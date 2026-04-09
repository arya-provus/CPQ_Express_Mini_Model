import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getApprovalHistory from '@salesforce/apex/QuoteController.getApprovalHistory';

export default class QuoteSummaryTab extends LightningElement {
    @api quoteRecord;

    @track approvalHistory = [];
    wiredHistoryResult;

    @wire(getApprovalHistory, { quoteId: '$quoteRecord.Id' })
    wiredHistory(result) {
        this.wiredHistoryResult = result;
        if (result.data) {
            this.approvalHistory = result.data.map(h => ({
                ...h,
                relativeTime: this.getRelativeTime(h.Action_Date__c),
                formattedDate: h.Action_Date__c ? new Date(h.Action_Date__c).toLocaleString() : ''
            }));
        }
    }

    // Public method for parent to trigger refresh
    @api
    refreshAuditTrail() {
        return refreshApex(this.wiredHistoryResult);
    }

    get status() { return this.quoteRecord?.Status || 'Draft'; }
    
    get isDraft() { return this.status === 'Draft'; }
    get isInReview() { return this.status === 'In Review'; }
    get isApproved() { return this.status === 'Approved'; }
    get isRejected() { return this.status === 'Rejected'; }

    get currentStep() {
        if (this.isDraft) return '1';
        if (this.isInReview) return '2';
        if (this.isApproved || this.isRejected) return '3';
        return '1';
    }

    get stepValue() {
        if (this.isRejected) return 'Rejected';
        if (this.isApproved) return 'Approved';
        return this.status;
    }

    get opportunityName() { return this.quoteRecord?.OpportunityName || this.quoteRecord?.Opportunity?.Name || '-'; }
    get accountName() { return this.quoteRecord?.AccountName || this.quoteRecord?.Opportunity?.Account?.Name || '-'; }
    get createdByName() { return this.quoteRecord?.CreatedByName || this.quoteRecord?.CreatedBy?.Name || 'System'; }
    
    get formattedCreatedDate() {
        return this.quoteRecord?.CreatedDate ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(this.quoteRecord.CreatedDate)) : '-';
    }

    get formattedExpirationDate() {
        return this.quoteRecord?.ExpirationDate ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(this.quoteRecord.ExpirationDate)) : '-';
    }

    get laborRevenue() {
        let total = this.quoteRecord?.Total_Amount__c || 0;
        return typeof total === 'number' ? total * 0.6 : 0;
    }

    get productRevenue() {
        let total = this.quoteRecord?.Total_Amount__c || 0;
        return typeof total === 'number' ? total * 0.3 : 0;
    }

    get addonRevenue() {
        let total = this.quoteRecord?.Total_Amount__c || 0;
        return typeof total === 'number' ? total * 0.1 : 0;
    }

    get hasApprovalHistory() {
        return this.approvalHistory && this.approvalHistory.length > 0;
    }

    getRelativeTime(dateString) {
        if (!dateString) return '';
        const diff = Date.now() - new Date(dateString).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'Just now';
        if (mins < 60) return `${mins} mins ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs} hrs ago`;
        const days = Math.floor(hrs / 24);
        return `${days} days ago`;
    }
}
