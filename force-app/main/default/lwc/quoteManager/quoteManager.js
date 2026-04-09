import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getQuotes from '@salesforce/apex/QuoteController.getQuotes';
import createQuote from '@salesforce/apex/QuoteController.createQuote';
import deleteQuotes from '@salesforce/apex/QuoteController.deleteQuotes';

const COLUMNS = [
    { label: '#', fieldName: 'index', type: 'number', initialWidth: 50 },
    { 
        label: 'ID', 
        fieldName: 'Id', 
        type: 'button',
        initialWidth: 100,
        typeAttributes: {
            label: { fieldName: 'QuoteNumber' },
            name: 'view_quote',
            variant: 'base',
            class: 'slds-text-link'
        }
    },

    { label: 'Opportunity', fieldName: 'OpportunityName', type: 'text' },
    { label: 'Account', fieldName: 'AccountName', type: 'text' },
    { 
        label: 'Status', 
        fieldName: 'Status', 
        type: 'text',
        cellAttributes: {
            class: { fieldName: 'statusBadgeClass' }
        }
    },
    { label: 'Created By', fieldName: 'CreatedByName', type: 'text' },
    { label: 'Created Date', fieldName: 'FormattedDate', type: 'text' },
    { label: 'Total Amount', fieldName: 'Total_Amount__c', type: 'currency' },
    { label: 'Discount %', fieldName: 'DiscountText', type: 'text' },
    { label: 'Margin %', fieldName: 'MarginText', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Copy', name: 'copy_quote', iconName: 'utility:copy' },
                { label: 'Delete', name: 'delete_quote', iconName: 'utility:delete' }
            ]
        }
    }
];

export default class QuoteManager extends NavigationMixin(LightningElement) {
    @track isModalOpen = false;
    @track quoteFields = {
        AccountId: null,
        OpportunityId: null,
        Description: '',
        StartDate: null,
        EndDate: null,
        TimePeriod: 'Months'
    };
    @track searchKey = '';
    @track statusFilter = 'All Status';
    @track accountFilter = 'All Accounts';
    @track quotes = [];
    @track columns = COLUMNS;
    @track selectedRows = [];
    @track selectedCount = 0;
    @track isConfirmOpen = false;
    @track confirmTitle = '';
    @track confirmMessage = '';
    pendingDeleteIds = null;
    wiredQuotesResult;

    timePeriodOptions = [
        { label: 'Months', value: 'Months' },
        { label: 'Years', value: 'Years' },
        { label: 'Weeks', value: 'Weeks' }
    ];

    // Fetch quotes using @wire
    @wire(getQuotes)
    wiredQuotes(result) {
        this.wiredQuotesResult = result;
        if (result.data) {
            this.quotes = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to fetch quotes', 'error');
        }
    }

    get formattedQuotes() {
        let filteredQuotes = this.quotes;
        if (this.searchKey) {
            const key = this.searchKey.toLowerCase();
            filteredQuotes = filteredQuotes.filter(q => 
                (q.Name && q.Name.toLowerCase().includes(key)) ||
                (q.QuoteNumber && q.QuoteNumber.toLowerCase().includes(key)) ||
                (q.Opportunity?.Name && q.Opportunity.Name.toLowerCase().includes(key)) ||
                (q.Account__r?.Name && q.Account__r.Name.toLowerCase().includes(key))
            );
        }
        if (this.statusFilter && this.statusFilter !== 'All Status') {
            filteredQuotes = filteredQuotes.filter(q => q.Status === this.statusFilter);
        }
        if (this.accountFilter && this.accountFilter !== 'All Accounts') {
            filteredQuotes = filteredQuotes.filter(q => (q.Account__r?.Name || 'N/A') === this.accountFilter);
        }

        return filteredQuotes.map((q, index) => {
            const margin = q.Margin__c != null ? q.Margin__c : 0;
            const discount = q.Discount__c != null ? q.Discount__c : 0;
            
            return {
                ...q,
                index: index + 1,
                AccountName: q.Account__r?.Name || 'N/A',
                OpportunityName: q.Opportunity?.Name || 'N/A',
                CreatedByName: q.CreatedBy?.Name || 'System',
                FormattedDate: q.CreatedDate ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(q.CreatedDate)) : '',
                DiscountText: discount > 0 ? `${discount}%` : '-',
                MarginText: margin > 0 ? `${margin}%` : '-',
                statusBadgeClass: this.getStatusBadgeClass(q.Status)
            };
        });
    }

    getStatusBadgeClass(status) {
        if (status === 'Rejected') {
            return 'slds-badge slds-theme_error status-pill-red';
        }
        return 'slds-badge slds-theme_light status-pill-gray';
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleStatusSelect(event) {
        this.statusFilter = event.detail.value;
    }

    handleAccountSelect(event) {
        this.accountFilter = event.detail.value;
    }

    get accountOptions() {
        // Extract unique account names
        let accounts = new Set();
        this.quotes.forEach(q => {
            const accName = q.Account__r?.Name;
            if (accName) accounts.add(accName);
        });
        const options = Array.from(accounts).map(acc => ({ label: acc, value: acc }));
        return [{ label: 'All Accounts', value: 'All Accounts' }, ...options];
    }

    get quoteCount() {
        return this.formattedQuotes.length;
    }

    get totalQuoteCount() {
        return this.quotes.length;
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    async handleRefresh() {
        await refreshApex(this.wiredQuotesResult);
        this.showToast('Success', 'Quotes refreshed', 'success');
    }

    get isCreateDisabled() {
        return !this.quoteFields.AccountId || !this.quoteFields.StartDate || !this.quoteFields.TimePeriod;
    }

    openModal() {
        // Set default start date to today
        const today = new Date().toISOString().split('T')[0];
        this.quoteFields.StartDate = today;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetFields();
    }

    resetFields() {
        this.quoteFields = {
            AccountId: null,
            OpportunityId: null,
            Description: '',
            StartDate: null,
            EndDate: null,
            TimePeriod: 'Months'
        };
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.quoteFields = { ...this.quoteFields, [field]: event.target.value };
    }

    handleAccountChange(event) {
        this.quoteFields = { ...this.quoteFields, AccountId: event.detail.recordId };
    }

    handleOpportunityChange(event) {
        this.quoteFields = { ...this.quoteFields, OpportunityId: event.detail.recordId };
    }

    async handleCreateQuote() {
        try {
            const startDate = this.quoteFields.StartDate ? new Date(this.quoteFields.StartDate).toISOString().split('T')[0] : null;
            const endDate = this.quoteFields.EndDate ? new Date(this.quoteFields.EndDate).toISOString().split('T')[0] : null;
            
            // Validate that start date does not exceed end date
            if (startDate && endDate && (new Date(startDate) > new Date(endDate))) {
                this.showToast('Error', 'Start date cannot exceed end date', 'error');
                return;
            }
            
            // Generate a default name since we removed it from UI
            const generatedName = 'Quote - ' + new Date().toLocaleDateString();

            await createQuote({ 
                name: generatedName,
                accountId: this.quoteFields.AccountId,
                opportunityId: this.quoteFields.OpportunityId,
                startDate: startDate,
                endDate: endDate
            });
            this.showToast('Success', 'Quote created successfully', 'success');
            this.closeModal();
            await refreshApex(this.wiredQuotesResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // Handle row action for navigation
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_quote') {
            const viewEvent = new CustomEvent('viewquote', {
                detail: { quoteId: row.Id }
            });
            this.dispatchEvent(viewEvent);
        } else if (actionName === 'copy_quote') {
            this.showToast('Info', 'Copy functionality not implemented yet', 'info');
        } else if (actionName === 'delete_quote') {
            this.handleDelete(row.Id);
        }
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
        this.selectedCount = this.selectedRows.length;
    }

    handleClearSelection() {
        this.template.querySelector('lightning-datatable').selectedRows = [];
        this.selectedRows = [];
        this.selectedCount = 0;
    }

    async handleBulkDelete() {
        const quoteIds = this.selectedRows.map(row => row.Id);
        await this.handleDelete(quoteIds);
    }

    handleDelete(ids) {
        const isBulk = Array.isArray(ids);
        this.pendingDeleteIds = isBulk ? ids : [ids];
        const count = this.pendingDeleteIds.length;
        
        this.confirmTitle = isBulk ? `Delete ${count} Quotes` : 'Delete Quote';
        this.confirmMessage = `Are you sure you want to delete ${count} quote${count > 1 ? 's' : ''}? This action cannot be undone.`;
        this.isConfirmOpen = true;
    }

    closeConfirm() {
        this.isConfirmOpen = false;
        this.pendingDeleteIds = null;
    }

    async executeDelete() {
        try {
            this.isConfirmOpen = false;
            await deleteQuotes({ quoteIds: this.pendingDeleteIds });
            
            this.showToast('Success', 'Quotes deleted successfully', 'success');
            this.handleClearSelection();
            await refreshApex(this.wiredQuotesResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // Navigation method
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    // Helper method for toast notifications
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
