import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getQuoteById from '@salesforce/apex/QuoteController.getQuoteById';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';
import updateQuoteLine from '@salesforce/apex/QuoteLineController.updateQuoteLine';
import deleteQuoteLine from '@salesforce/apex/QuoteLineController.deleteQuoteLine';
import submitForApproval from '@salesforce/apex/QuoteController.submitForApproval';
import recallQuote from '@salesforce/apex/QuoteController.recallQuote';
import approveQuote from '@salesforce/apex/QuoteController.approveQuote';
import rejectQuote from '@salesforce/apex/QuoteController.rejectQuote';
import getApprovalHistory from '@salesforce/apex/QuoteController.getApprovalHistory';

// Static read-only columns — NO editable flag at all, NO action column
const READ_ONLY_COLUMNS = [
    { label: 'Resource / Product', fieldName: 'displayName', type: 'text' },
    { label: 'Task', fieldName: 'Task__c', type: 'text' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
    { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
    { label: 'Base Rate', fieldName: 'Base_Rate__c', type: 'currency' },
    { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency' },
    { label: 'Discount %', fieldName: 'Discount__c', type: 'number',
      typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 } },
    { label: 'Total Price', fieldName: 'calculatedTotal', type: 'currency' }
];

// Static editable columns — full editing + delete action
const EDIT_COLUMNS = [
    { label: 'Resource / Product', fieldName: 'displayName', type: 'text' },
    { label: 'Task', fieldName: 'Task__c', type: 'text', editable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', editable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date', editable: true },
    { label: 'Quantity', fieldName: 'Quantity', type: 'number', editable: true },
    { label: 'Base Rate', fieldName: 'Base_Rate__c', type: 'currency' },
    { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency', editable: true },
    { label: 'Discount %', fieldName: 'Discount__c', type: 'number', editable: true,
      typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 } },
    { label: 'Total Price', fieldName: 'calculatedTotal', type: 'currency' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Delete', name: 'delete_line' }] }
    }
];

export default class QuoteDetail extends LightningElement {
    @api recordId;
    @track quote = {};
    @track lineItems = [];
    @track approvalHistory = [];
    @track isApprovalModalOpen = false;
    @track isLineItemModalOpen = false;
    @track approvalComments = '';
    @track draftValues = [];
    @track currentAction = '';
    @track modalTitle = '';
    @track modalConfirmLabel = '';
    @track modalConfirmVariant = 'brand';
    @track modalSubtitle = '';

    readOnlyColumns = READ_ONLY_COLUMNS;
    editColumns = EDIT_COLUMNS;

    wiredQuoteResult;
    wiredLinesResult;

    @wire(getQuoteById, { quoteId: '$recordId' })
    wiredQuote(result) {
        this.wiredQuoteResult = result;
        if (result.data) {
            this.quote = result.data;
        }
    }

    @wire(getQuoteLines, { quoteId: '$recordId' })
    wiredLines(result) {
        this.wiredLinesResult = result;
        if (result.data) {
            this.lineItems = result.data;
        }
    }

    @wire(getApprovalHistory, { quoteId: '$recordId' })
    wiredHistory(result) {
        if (result.data) {
            this.approvalHistory = result.data.map(h => ({
                ...h,
                relativeTime: this.getRelativeTime(h.Action_Date__c),
                formattedDate: h.Action_Date__c
                    ? new Date(h.Action_Date__c).toLocaleString('en-US', {
                        month: 'short', day: 'numeric', year: 'numeric',
                        hour: 'numeric', minute: '2-digit'
                      })
                    : ''
            }));
        }
    }

    // ── Core Status Getters ──────────────────────────────────────────────

    get rawStatus() { return this.quote.Status || 'Draft'; }

    /** True whenever the quote must NOT be edited */
    get isLocked() {
        return this.rawStatus === 'In Review'
            || this.rawStatus === 'Approved'
            || this.rawStatus === 'Rejected';
    }

    /** Display label — maps "In Review" → "Pending Approval" */
    get quoteStatus() {
        return this.rawStatus === 'In Review' ? 'Pending Approval' : this.rawStatus;
    }

    get quoteName() { return this.quote.Name || 'Quote'; }
    get quoteNumber() { return this.quote.QuoteNumber || ''; }

    get accountName() {
        return this.quote.Account__r ? this.quote.Account__r.Name : 'N/A';
    }

    get statusBadgeClass() {
        const map = {
            'Draft': 'status-badge status-draft',
            'In Review': 'status-badge status-in-review',
            'Approved': 'status-badge status-approved',
            'Rejected': 'status-badge status-rejected'
        };
        return map[this.rawStatus] || 'status-badge status-draft';
    }

    // ── Button Visibility ────────────────────────────────────────────────

    get canSubmit()  { return this.rawStatus === 'Draft'; }
    get canRecall()  { return this.rawStatus === 'In Review'; }
    get canApprove() { return this.rawStatus === 'In Review'; }
    get canReject()  { return this.rawStatus === 'In Review'; }

    // ── Datatable Rendering (two separate tables, not one with dynamic cols) ──

    get showEditableTable()  { return this.hasLineItems && !this.isLocked; }
    get showReadOnlyTable()  { return this.hasLineItems && this.isLocked; }

    // ── Formatters ───────────────────────────────────────────────────────

    get formattedSubtotal() { return this.formatCurrency(this.quote.Subtotal__c); }
    get formattedDiscount() { return this.formatPercent(this.quote.Discount__c); }
    get formattedMargin()   { return this.formatPercent(this.quote.Margin__c); }
    get formattedTotal()    { return this.formatCurrency(this.quote.Total_Amount__c); }

    get formattedCreatedDate() {
        return this.quote.CreatedDate
            ? new Date(this.quote.CreatedDate).toLocaleDateString() : 'N/A';
    }
    get formattedExpirationDate() {
        return this.quote.ExpirationDate
            ? new Date(this.quote.ExpirationDate).toLocaleDateString() : 'N/A';
    }

    get lineItemsTabLabel() { return `Line Items (${this.lineItems.length})`; }
    get hasLineItems()      { return this.lineItems && this.lineItems.length > 0; }
    get hasApprovalHistory(){ return this.approvalHistory && this.approvalHistory.length > 0; }

    get formattedLineItems() {
        return this.lineItems.map(line => {
            const discount = line.Discount__c || 0;
            const unitPrice = line.UnitPrice || 0;
            const quantity = line.Quantity || 1;
            const calculatedTotal = unitPrice * quantity * (1 - discount / 100);
            let displayName = line.Product2 ? line.Product2.Name : 'Unknown';
            if (line.Resource_Role__r && line.Resource_Role__r.Name) {
                displayName = line.Resource_Role__r.Name;
            }
            return { ...line, displayName, calculatedTotal };
        });
    }

    formatCurrency(value) {
        const num = value || 0;
        return '$' + Number(num).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    formatPercent(value) {
        const num = value || 0;
        return Number(num).toFixed(2) + '%';
    }

    getRelativeTime(dateString) {
        if (!dateString) return '';
        const diff = Date.now() - new Date(dateString).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'just now';
        if (mins < 60) return `${mins} minute${mins > 1 ? 's' : ''} ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs} hour${hrs > 1 ? 's' : ''} ago`;
        const days = Math.floor(hrs / 24);
        return `${days} day${days > 1 ? 's' : ''} ago`;
    }

    // ── Actions ──────────────────────────────────────────────────────────

    handleAddLineItems() { this.isLineItemModalOpen = true; }
    closeLineItemModal() { this.isLineItemModalOpen = false; this.refreshData(); }
    handleLineItemsAdded() { this.closeLineItemModal(); this.showToast('Success', 'Line items added', 'success'); }
    handleGeneratePdf() { this.showToast('Info', 'PDF generation started...', 'info'); }

    // ── Approval Modal ───────────────────────────────────────────────────

    openSubmitModal() {
        if (this.draftValues.length > 0) {
            this.showToast('Warning', 'Please save your unsaved changes before submitting.', 'warning');
            return;
        }
        this.modalTitle = 'Submit Quote for Approval';
        this.modalSubtitle = `Submit quote "${this.quoteName}" for approval.`;
        this.modalConfirmLabel = 'Submit for Approval';
        this.modalConfirmVariant = 'brand';
        this.currentAction = 'submit';
        this.approvalComments = '';
        this.isApprovalModalOpen = true;
    }

    openApproveModal() {
        this.modalTitle = 'Approve Quote';
        this.modalSubtitle = `Approve quote "${this.quoteName}".`;
        this.modalConfirmLabel = 'Approve';
        this.modalConfirmVariant = 'success';
        this.currentAction = 'approve';
        this.approvalComments = '';
        this.isApprovalModalOpen = true;
    }

    openRejectModal() {
        this.modalTitle = 'Reject Quote';
        this.modalSubtitle = `Reject quote "${this.quoteName}".`;
        this.modalConfirmLabel = 'Reject';
        this.modalConfirmVariant = 'destructive';
        this.currentAction = 'reject';
        this.approvalComments = '';
        this.isApprovalModalOpen = true;
    }

    closeApprovalModal() {
        this.isApprovalModalOpen = false;
        this.approvalComments = '';
    }

    handleApprovalCommentChange(event) {
        this.approvalComments = event.target.value;
    }

    async handleActionConfirm() {
        if (!this.approvalComments || !this.approvalComments.trim()) {
            this.showToast('Error', 'Comments are required before proceeding.', 'error');
            return;
        }
        try {
            const params = { quoteId: this.recordId, comments: this.approvalComments };
            if (this.currentAction === 'submit')  await submitForApproval(params);
            if (this.currentAction === 'approve') await approveQuote(params);
            if (this.currentAction === 'reject')  await rejectQuote(params);

            const msgMap = { submit: 'submitted for approval', approve: 'approved', reject: 'rejected' };
            this.showToast('Success', `Quote ${msgMap[this.currentAction] || 'updated'} successfully.`, 'success');
            this.closeApprovalModal();
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleRecall() {
        try {
            await recallQuote({ quoteId: this.recordId });
            this.showToast('Success', 'Quote recalled to Draft.', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ── Inline Editing (only reachable when isLocked = false) ───────────

    async handleLineSave(event) {
        const draftValues = event.detail.draftValues;
        try {
            await Promise.all(draftValues.map(draft =>
                updateQuoteLine({
                    lineId: draft.Id,
                    discount: draft.Discount__c != null ? draft.Discount__c : null,
                    task: draft.Task__c != null ? draft.Task__c : null,
                    startDate: draft.Start_Date__c != null ? draft.Start_Date__c : null,
                    endDate: draft.End_Date__c != null ? draft.End_Date__c : null,
                    unitPrice: draft.UnitPrice != null ? draft.UnitPrice : null,
                    quantity: draft.Quantity != null ? draft.Quantity : null
                })
            ));
            this.draftValues = [];
            this.showToast('Success', 'Line items updated.', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleLineAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'delete_line') {
            try {
                await deleteQuoteLine({ lineId: row.Id });
                this.showToast('Success', 'Line item deleted.', 'success');
                await this.refreshData();
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            }
        }
    }

    // ── Utility ──────────────────────────────────────────────────────────

    async refreshData() {
        await Promise.all([
            refreshApex(this.wiredQuoteResult),
            refreshApex(this.wiredLinesResult)
        ]);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
