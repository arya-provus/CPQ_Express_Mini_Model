import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getQuoteSummary from '@salesforce/apex/QuoteController.getQuoteSummary';

export default class CpqDashboard extends LightningElement {
    // ── Tracked state ────────────────────────────────────────────────
    @track draftCount = 0;
    @track highMarginCount = 0;
    @track wonCount = 0;
    @track totalPipelineAmount = 0;
    @track highMarginAmount = 0;
    @track recentQuotes = [];
    @track activeTab = 'all';

    wiredSummaryResult;

    // ── Wire: fetch summary data ─────────────────────────────────────
    @wire(getQuoteSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        const { data, error } = result;
        if (data) {
            this.draftCount         = data.draftCount || 0;
            this.highMarginCount    = data.highMarginCount || 0;
            this.wonCount           = data.wonCount || 0;
            this.totalPipelineAmount = data.totalPipelineAmount || 0;
            this.highMarginAmount   = data.highMarginAmount || 0;

            if (data.recentQuotes) {
                this.recentQuotes = data.recentQuotes.map(q => ({
                    ...q,
                    formattedAmount: q.Total_Amount__c
                        ? '$' + Number(q.Total_Amount__c).toLocaleString('en-US', { minimumFractionDigits: 0 })
                        : '$0',
                    timeAgo: this.getRelativeTime(q.CreatedDate),
                    statusPillClass: this.getStatusPillClass(q.Status)
                }));
            }
        } else if (error) {
            console.error('Dashboard wire error:', error);
        }
    }

    // ── Computed Insight Counts ──────────────────────────────────────

    get pendingCount() {
        return this.recentQuotes.filter(q => q.Status === 'In Review').length;
    }

    get pendingAmountFormatted() {
        const total = this.recentQuotes
            .filter(q => q.Status === 'In Review')
            .reduce((sum, q) => sum + (q.Total_Amount__c || 0), 0);
        return '$' + Number(total).toLocaleString('en-US', { minimumFractionDigits: 0 });
    }

    get lowMarginCount() {
        return this.recentQuotes.filter(q => q.Status === 'Draft' && (q.Margin__c || 0) < 15).length;
    }

    get draftPipelineFormatted() {
        return '$' + Number(this.totalPipelineAmount).toLocaleString('en-US', { minimumFractionDigits: 0 });
    }

    get highMarginAmountFormatted() {
        return '$' + Number(this.highMarginAmount).toLocaleString('en-US', { minimumFractionDigits: 0 });
    }

    get wonAmountFormatted() {
        const total = this.recentQuotes
            .filter(q => q.Status === 'Approved')
            .reduce((sum, q) => sum + (q.Total_Amount__c || 0), 0);
        return '$' + Number(total).toLocaleString('en-US', { minimumFractionDigits: 0 });
    }

    get totalQuoteCount() {
        return this.recentQuotes.length;
    }

    // ── Filtered Panel Quotes ────────────────────────────────────────

    get filteredPanelQuotes() {
        if (this.activeTab === 'all') return this.recentQuotes;
        const filterMap = {
            draft:    'Draft',
            pending:  'In Review',
            approved: 'Approved',
            rejected: 'Rejected'
        };
        const status = filterMap[this.activeTab];
        return status ? this.recentQuotes.filter(q => q.Status === status) : this.recentQuotes;
    }

    get hasFilteredQuotes() {
        return this.filteredPanelQuotes && this.filteredPanelQuotes.length > 0;
    }

    get dynamicPanelTitle() {
        if (this.activeTab === 'all') return 'All Quotes';
        if (this.activeTab === 'draft') return 'Your Draft Quotes';
        if (this.activeTab === 'pending') return 'Pending Quotes';
        if (this.activeTab === 'approved') return 'Approved Quotes';
        if (this.activeTab === 'rejected') return 'Rejected Quotes';
        return 'All Quotes';
    }

    get filteredQuoteCount() {
        return this.hasFilteredQuotes ? this.filteredPanelQuotes.length : 0;
    }

    // ── Tab Classes ──────────────────────────────────────────────────
    get allTabClass()      { return this.activeTab === 'all'      ? 'tab-btn tab-active' : 'tab-btn'; }
    get draftTabClass()    { return this.activeTab === 'draft'    ? 'tab-btn tab-active' : 'tab-btn'; }
    get pendingTabClass()  { return this.activeTab === 'pending'  ? 'tab-btn tab-active' : 'tab-btn'; }
    get approvedTabClass() { return this.activeTab === 'approved' ? 'tab-btn tab-active' : 'tab-btn'; }
    get rejectedTabClass() { return this.activeTab === 'rejected' ? 'tab-btn tab-active' : 'tab-btn'; }

    // ── Tab Handlers ─────────────────────────────────────────────────
    handleTabAll()      { this.activeTab = 'all'; }
    handleTabDraft()    { this.activeTab = 'draft'; }
    handleTabPending()  { this.activeTab = 'pending'; }
    handleTabApproved() { this.activeTab = 'approved'; }
    handleTabRejected() { this.activeTab = 'rejected'; }

    // ── Card Click → navigate to Quotes page ────────────────────────
    handleViewPending() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    handleViewLowMargin() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    handleViewDrafts() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    handleViewHighMargin() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    handleViewWon() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    // ── Quote Row Click ──────────────────────────────────────────────
    handleQuoteClick(event) {
        const quoteId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewquote', { detail: { quoteId } }));
    }

    // ── Create Quote → navigate to Quotes page ───────────────────────
    handleCreateQuote() {
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'quotes' }, bubbles: true, composed: true
        }));
    }

    // ── Refresh ──────────────────────────────────────────────────────
    async handleRefresh() {
        await refreshApex(this.wiredSummaryResult);
    }

    // ── Helpers ──────────────────────────────────────────────────────

    getRelativeTime(dateString) {
        if (!dateString) return '';
        const diff = Date.now() - new Date(dateString).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1)  return 'just now';
        if (mins < 60) return `${mins}m ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24)  return `${hrs}h ago`;
        const days = Math.floor(hrs / 24);
        return `${days}d ago`;
    }

    getStatusPillClass(status) {
        const map = {
            'Draft':     'status-pill pill-draft',
            'In Review': 'status-pill pill-pending',
            'Approved':  'status-pill pill-approved',
            'Rejected':  'status-pill pill-rejected'
        };
        return map[status] || 'status-pill pill-draft';
    }
}
