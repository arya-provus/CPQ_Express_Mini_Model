import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveProducts from '@salesforce/apex/ProductController.getActiveProducts';
import getActiveRoles from '@salesforce/apex/ResourceRoleController.getActiveRoles';
import getActiveAddOns from '@salesforce/apex/AddOnController.getActiveAddOns';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';
import addQuoteLine from '@salesforce/apex/QuoteLineController.addQuoteLine';
import addResourceRoleLine from '@salesforce/apex/QuoteLineController.addResourceRoleLine';
import getQuoteById from '@salesforce/apex/QuoteController.getQuoteById';

const PRODUCT_COLUMNS = [
    { label: 'Name', fieldName: 'ProductName', type: 'text' },
    { label: 'Price', fieldName: 'UnitPrice', type: 'currency' },
    { label: 'Description', fieldName: 'Description', type: 'text' }
];

const ROLE_COLUMNS = [
    { label: 'Role Name', fieldName: 'Name', type: 'text' },
    { label: 'Category', fieldName: 'Category__c', type: 'text' },
    { label: 'Base Rate', fieldName: 'Base_Rate__c', type: 'currency' }
];

const ADDON_COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Price', fieldName: 'Price__c', type: 'currency' },
    { label: 'Description', fieldName: 'Description__c', type: 'text' }
];

const LINE_COLUMNS = [
    { label: 'Product / Role', fieldName: 'ProductName', type: 'text' },
    { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
    { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency' },
    { label: 'Total Price', fieldName: 'TotalPrice', type: 'currency' }
];

export default class QuoteLineManager extends LightningElement {
    @api recordId;
    @track availableProducts = [];
    @track filteredProducts = [];
    @track availableRoles = [];
    @track availableAddOns = [];
    @track quoteLines = [];
    @track selectedRows = [];
    @track selectedRoles = [];
    @track selectedAddons = [];
    @track searchQuery = '';
    @track isLocked = false;

    productColumns = PRODUCT_COLUMNS;
    roleColumns = ROLE_COLUMNS;
    addonColumns = ADDON_COLUMNS;
    lineColumns = LINE_COLUMNS;

    wiredProductsResult;
    wiredLinesResult;
    wiredRolesResult;
    wiredAddOnsResult;

    @wire(getQuoteById, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            this.isLocked = data.Is_Locked__c;
        }
    }

    @wire(getActiveProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        if (result.data) {
            this.availableProducts = result.data.map(pbe => ({
                Id: pbe.Id,
                Product2Id: pbe.Product2Id,
                ProductName: pbe.Product2.Name,
                UnitPrice: pbe.UnitPrice,
                Description: pbe.Product2.Description
            }));
            this.filterProducts();
        }
    }

    @wire(getActiveRoles)
    wiredRoles(result) {
        this.wiredRolesResult = result;
        if (result.data) {
            this.availableRoles = result.data;
        }
    }

    @wire(getActiveAddOns)
    wiredAddOns(result) {
        this.wiredAddOnsResult = result;
        if (result.data) {
            this.availableAddOns = result.data;
        }
    }

    @wire(getQuoteLines, { quoteId: '$recordId' })
    wiredLines(result) {
        this.wiredLinesResult = result;
        if (result.data) {
            this.quoteLines = result.data;
        }
    }

    // Computed properties
    get hasRoles() { return this.availableRoles && this.availableRoles.length > 0; }
    get hasAddOns() { return this.availableAddOns && this.availableAddOns.length > 0; }

    get roleTabLabel() {
        return `Resource Roles (${this.availableRoles ? this.availableRoles.length : 0})`;
    }
    get addonTabLabel() {
        return `Add-ons (${this.availableAddOns ? this.availableAddOns.length : 0})`;
    }

    get formattedQuoteLines() {
        return this.quoteLines.map(line => ({
            ...line,
            ProductName: line.Product2 ? line.Product2.Name : 'Unknown'
        }));
    }

    // Products
    get isAddDisabled() { return this.selectedRows.length === 0 || this.isLocked; }
    get addLabel() {
        if (this.isLocked) return 'Quote Locked';
        const count = this.selectedRows.length;
        return count > 1 ? `Add ${count} Items` : count === 1 ? 'Add 1 Item' : 'Add Item';
    }

    // Roles
    get isAddRolesDisabled() { return this.selectedRoles.length === 0 || this.isLocked; }
    get addRoleLabel() {
        if (this.isLocked) return 'Quote Locked';
        const count = this.selectedRoles.length;
        return count > 1 ? `Add ${count} Roles` : count === 1 ? 'Add 1 Role' : 'Add Role';
    }

    // Add-ons
    get isAddAddonsDisabled() { return this.selectedAddons.length === 0 || this.isLocked; }
    get addAddonLabel() {
        if (this.isLocked) return 'Quote Locked';
        const count = this.selectedAddons.length;
        return count > 1 ? `Add ${count} Add-ons` : count === 1 ? 'Add 1 Add-on' : 'Add Add-on';
    }

    handleSearchChange(event) {
        this.searchQuery = event.target.value.toLowerCase();
        this.filterProducts();
    }

    filterProducts() {
        if (!this.searchQuery) {
            this.filteredProducts = [...this.availableProducts];
        } else {
            this.filteredProducts = this.availableProducts.filter(p => 
                p.ProductName.toLowerCase().includes(this.searchQuery) ||
                (p.Description && p.Description.toLowerCase().includes(this.searchQuery))
            );
        }
    }

    handleRowSelection(event) { this.selectedRows = event.detail.selectedRows; }
    handleRoleSelection(event) { this.selectedRoles = event.detail.selectedRows; }
    handleAddonSelection(event) { this.selectedAddons = event.detail.selectedRows; }

    async handleAddItems() {
        if (this.isLocked) return;
        try {
            const promises = this.selectedRows.map(row => 
                addQuoteLine({
                    quoteId: this.recordId,
                    productId: row.Product2Id,
                    quantity: 1
                })
            );
            await Promise.all(promises);
            this.showToast('Success', `${this.selectedRows.length} item(s) added to quote`, 'success');
            this.selectedRows = [];
            this.clearDatatableSelection();
            await refreshApex(this.wiredLinesResult);
            this.fireLineItemsAdded();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleAddRoles() {
        if (this.isLocked) return;
        try {
            const promises = this.selectedRoles.map(role => 
                addResourceRoleLine({
                    quoteId: this.recordId,
                    roleId: role.Id,
                    quantity: 1
                })
            );
            await Promise.all(promises);
            this.showToast('Success', `${this.selectedRoles.length} role(s) added to quote`, 'success');
            this.selectedRoles = [];
            await refreshApex(this.wiredLinesResult);
            this.fireLineItemsAdded();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleAddAddons() {
        // Add-ons are treated as products - would need a similar mechanism
        // For now, show info toast
        this.showToast('Info', 'Add-on line items feature coming soon. Use Products tab for now.', 'info');
    }

    handleCancel() { this.selectedRows = []; this.clearDatatableSelection(); }
    handleCancelRoles() { this.selectedRoles = []; }
    handleCancelAddons() { this.selectedAddons = []; }

    clearDatatableSelection() {
        const dts = this.template.querySelectorAll('lightning-datatable');
        dts.forEach(dt => { dt.selectedRows = []; });
    }

    fireLineItemsAdded() {
        this.dispatchEvent(new CustomEvent('lineitemsadded'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
