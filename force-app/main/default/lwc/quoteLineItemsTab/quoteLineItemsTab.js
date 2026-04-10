import { LightningElement, api, wire, track } from 'lwc';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';
import addItemsToQuote from '@salesforce/apex/QuoteLineController.addItemsToQuote';
import deleteQuoteLine from '@salesforce/apex/QuoteLineController.deleteQuoteLine';
import updateQuoteLines from '@salesforce/apex/QuoteLineController.updateQuoteLines';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuoteLineItemsTab extends LightningElement {
    @api quoteId;
    @api isLocked = false;
    @track lineItems = [];
    @track isModalOpen = false;
    @track activeTabName = 'roles';
    @track draftValues = [];
    @track columns = [];
    wiredLinesResult;

    connectedCallback() {
        this.updateColumns();
    }

    // React to lock changes to refresh columns
    @api
    set lockState(value) {
        this.isLocked = value;
        this.updateColumns();
    }
    get lockState() {
        return this.isLocked;
    }

    updateColumns() {
        const editable = !this.isLocked;
        this.columns = [
            { label: 'Name', fieldName: 'itemName', type: 'text' },
            { label: 'Task', fieldName: 'Task__c', type: 'text', editable: editable },
            { label: 'Qty', fieldName: 'Quantity', type: 'number', editable: editable, initialWidth: 70 },
            { label: 'Base Rate', fieldName: 'Base_Rate__c', type: 'currency', editable: editable },
            { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency' },
            { label: 'Disc %', fieldName: 'Discount__c', type: 'number', editable: editable, initialWidth: 80 },
            { label: 'Disc Amt', fieldName: 'discountAmount', type: 'currency', initialWidth: 100 },
            { label: 'Line Total', fieldName: 'lineTotal', type: 'currency', cellAttributes: { class: 'slds-text-title_caps slds-text-color_success' } },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: !this.isLocked ? [
                        { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
                    ] : []
                }
            }
        ];
    }

    @wire(getQuoteLines, { quoteId: '$quoteId' })
    wiredLines(result) {
        this.wiredLinesResult = result;
        if (result.data) {
            this.lineItems = result.data.map(line => {
                let name = 'Unknown Item';
                if (line.Resource_Role__c && line.Resource_Role__r) {
                    name = line.Resource_Role__r.Name;
                } else if (line.Product2 && line.Product2.Name) {
                    name = line.Product2.Name;
                }
                
                const prodName = (line.Product2 && line.Product2.Name) ? line.Product2.Name : '';
                let itemType = 'Product';
                if (line.Resource_Role__c) {
                    itemType = 'Resource Role';
                } else if (prodName && prodName.startsWith('Add-on:')) {
                    itemType = 'Add-On';
                }

                const qty = line.Quantity || 0;
                const price = line.UnitPrice || 0;
                const discPct = line.Discount__c || 0;
                const cost = line.Cost__c || 0;
                
                const lineTotal = (price * qty);
                const discAmt = (lineTotal * (discPct / 100));
                const subtotal = lineTotal - discAmt;

                return {
                    ...line,
                    itemName: name,
                    itemType: itemType,
                    discountAmount: discAmt.toFixed(2),
                    lineTotal: subtotal.toFixed(2),
                    costValue: cost * qty
                };
            });
            this.calculateProjectedTotals();
            this.updateColumns(); // Refresh on data load
        } else if (result.error) {
            console.error('Error fetching lines', result.error);
        }
    }

    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;
        this.calculateProjectedTotals();
    }

    calculateProjectedTotals() {
        let totalSubtotal = 0;
        let totalCostLineByLine = 0;
        let totalDiscount = 0;
        
        let collectiveBaseRate = 0;
        let collectiveCost = 0;

        const projectedLines = this.lineItems.map(item => {
            const draft = this.draftValues.find(d => d.Id === item.Id) || {};
            
            const qty = draft.Quantity !== undefined ? parseFloat(draft.Quantity) : (item.Quantity || 0);
            const baseRate = draft.Base_Rate__c !== undefined ? parseFloat(draft.Base_Rate__c) : (item.Base_Rate__c || 0);
            const discPct = draft.Discount__c !== undefined ? parseFloat(draft.Discount__c) : (item.Discount__c || 0);
            const cost = item.Cost__c || 0;

            collectiveBaseRate += baseRate;
            collectiveCost += cost;

            const multiplier = item.Base_Rate__c ? (item.UnitPrice / item.Base_Rate__c) : 1;
            const calculatedPrice = baseRate * multiplier;

            const lineTotalRaw = calculatedPrice * qty;
            const lineTotal = Math.round(lineTotalRaw * 100) / 100;
            const discAmtRaw = lineTotal * (discPct / 100);
            const discAmt = Math.round(discAmtRaw * 100) / 100;
            const subtotal = Math.round((lineTotal - discAmt) * 100) / 100;

            totalSubtotal += lineTotal;
            totalDiscount += discAmt;
            totalCostLineByLine += (cost * multiplier * qty);

            return {
                ...item,
                Quantity: qty,
                Base_Rate__c: baseRate,
                UnitPrice: calculatedPrice,
                Discount__c: discPct,
                discountAmount: discAmt.toFixed(2),
                lineTotal: subtotal.toFixed(2)
            };
        });

        const marginAmount = collectiveBaseRate - collectiveCost;
        const marginPct = collectiveBaseRate > 0 ? (marginAmount / collectiveBaseRate) * 100 : 0;

        const summary = {
            subtotal: totalSubtotal,
            discount: totalDiscount,
            totalAmount: totalSubtotal - totalDiscount,
            totalCost: totalCostLineByLine,
            marginAmount: marginAmount,
            marginPct: marginPct
        };

        this.dispatchEvent(new CustomEvent('totalsupdate', {
            detail: summary
        }));
    }

    openModal() {
        if (this.isLocked) return;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    @api
    handleRefresh() {
        return refreshApex(this.wiredLinesResult);
    }

    handleTabActive(event) {
        this.activeTabName = event.target.value;
    }

    async handleAddSelected() {
        if (this.isLocked) return;
        const roleComp = this.template.querySelector('c-resource-role-manager');
        const prodComp = this.template.querySelector('c-product-manager');
        const addonComp = this.template.querySelector('c-add-on-manager');

        const roleIds = roleComp ? roleComp.getSelectedRows().map(r => r.Id) : [];
        const prodIds = prodComp ? prodComp.getSelectedRows().map(r => r.Id) : [];
        const addonIds = addonComp ? addonComp.getSelectedRows().map(r => r.Id) : [];

        if (roleIds.length === 0 && prodIds.length === 0 && addonIds.length === 0) {
            this.showToast('Warning', 'Please select at least one item from any tab to add.', 'warning');
            return;
        }

        try {
            await addItemsToQuote({
                quoteId: this.quoteId,
                productIds: prodIds,
                roleIds: roleIds,
                addonIds: addonIds
            });
            
            this.showToast('Success', 'Items added to quote successfully.', 'success');
            this.closeModal();
            this.handleRefresh();
            this.dispatchEvent(new CustomEvent('lineschanged'));
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleRowAction(event) {
        if (this.isLocked) return;
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'delete') {
            try {
                await deleteQuoteLine({ lineId: row.Id });
                this.showToast('Success', 'Item removed', 'success');
                this.handleRefresh();
                this.dispatchEvent(new CustomEvent('lineschanged'));
            } catch (error) {
                this.showToast('Error', 'Failed to delete line item', 'error');
            }
        }
    }

    @api
    async save() {
        if (this.draftValues.length === 0 || this.isLocked) {
            return;
        }

        try {
            await updateQuoteLines({ items: this.draftValues });
            this.showToast('Success', 'Quote lines saved successfully.', 'success');
            this.draftValues = [];
            await this.handleRefresh();
            this.dispatchEvent(new CustomEvent('lineschanged'));
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            throw error;
        }
    }

    handleInlineSave(event) {
        this.draftValues = event.detail.draftValues;
        this.save();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
