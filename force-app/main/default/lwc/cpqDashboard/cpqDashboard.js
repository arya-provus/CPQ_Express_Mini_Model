import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getQuoteSummary from '@salesforce/apex/QuoteController.getQuoteSummary';

export default class CpqDashboard extends NavigationMixin(LightningElement) {
    @track draftCount = 0;
    @track highMarginCount = 0;
    @track wonCount = 0;
    @track totalPipelineAmount = 0;
    @track recentQuotes = [];
    wiredSummaryResult;

    @wire(getQuoteSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        const { data, error } = result;
        if (data) {
            this.draftCount = data.draftCount || 0;
            this.highMarginCount = data.highMarginCount || 0;
            this.wonCount = data.wonCount || 0;
            this.totalPipelineAmount = data.totalPipelineAmount || 0;

            if (data.recentQuotes) {
                this.recentQuotes = data.recentQuotes.map(q => ({
                    ...q,
                    AccountName: q.Opportunity && q.Opportunity.Account ? q.Opportunity.Account.Name : '',
                    formattedAmount: q.Total_Amount__c 
                        ? '$' + Number(q.Total_Amount__c).toLocaleString('en-US', { minimumFractionDigits: 2 }) 
                        : '$0.00',
                    formattedDate: q.CreatedDate ? new Date(q.CreatedDate).toLocaleDateString() : '',
                    statusClass: this.getStatusClass(q.Status)
                }));
            }
        } else if (error) {
            console.error('Dashboard error:', error);
        }
    }

    get draftPipelineFormatted() {
        return '$' + Number(this.totalPipelineAmount).toLocaleString('en-US', { minimumFractionDigits: 2 });
    }

    get hasRecentQuotes() {
        return this.recentQuotes && this.recentQuotes.length > 0;
    }

    getStatusClass(status) {
        const statusMap = {
            'Draft': 'status-badge status-draft',
            'Approved': 'status-badge status-approved',
            'Rejected': 'status-badge status-rejected',
            'Needs Review': 'status-badge status-review'
        };
        return statusMap[status] || 'status-badge status-draft';
    }

    handleQuoteClick(event) {
        const quoteId = event.currentTarget.dataset.id;
        const viewEvent = new CustomEvent('viewquote', {
            detail: { quoteId: quoteId }
        });
        this.dispatchEvent(viewEvent);
    }

    async handleRefresh() {
        await refreshApex(this.wiredSummaryResult);
    }
}
