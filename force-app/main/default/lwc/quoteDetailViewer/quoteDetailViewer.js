import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteById from '@salesforce/apex/QuoteController.getQuoteById';
import { refreshApex } from '@salesforce/apex';

// Apex Approval Imports
import submitForApproval from '@salesforce/apex/QuoteController.submitForApproval';
import recallQuote from '@salesforce/apex/QuoteController.recallQuote';
import approveQuote from '@salesforce/apex/QuoteController.approveQuote';
import rejectQuote from '@salesforce/apex/QuoteController.rejectQuote';
import hasCPQStandardUser from '@salesforce/customPermission/CPQ_Standard_User';
import currentUserId from '@salesforce/user/Id';

export default class QuoteDetailViewer extends LightningElement {
    @api quoteId;
    @track quote;
    @track isLoading = true;
    @track error;
    @track activeTab = 'summary';
    @track projectedTotals;
    wiredQuoteResult;

    // Modal State
    @track isModalOpen = false;
    @track modalTitle = '';
    @track modalConfirmLabel = '';
    @track modalConfirmVariant = '';
    @track currentAction = '';

    @track isPdfModalOpen = false;

    @wire(getQuoteById, { quoteId: '$quoteId' })
    wiredQuote(result) {
        this.wiredQuoteResult = result;
        const { error, data } = result;
        this.isLoading = true;
        if (data) {
            this.quote = data;
            this.error = undefined;
            this.projectedTotals = undefined;
        } else if (error) {
            this.error = error;
            this.quote = undefined;
        }
        this.isLoading = false;
    }

    // ── Computed getters ─────────────────────────────────────────────────

    get quoteNumber() { return this.quote?.QuoteNumber || ''; }
    
    get rawStatus() { return this.quote?.Status || 'Draft'; }

    get statusLabel() {
        return this.rawStatus === 'In Review' ? 'Pending Approval' : this.rawStatus;
    }

    get isCreator() {
        return this.quote?.CreatedById === currentUserId;
    }

    get isLocked() {
        const statusLocked = this.rawStatus === 'In Review'
            || this.rawStatus === 'Approved'
            || this.rawStatus === 'Rejected';
            
        if (hasCPQStandardUser) {
            return statusLocked || !this.isCreator;
        }
        return statusLocked;
    }

    get canSubmit()  { 
        if (hasCPQStandardUser) return this.rawStatus === 'Draft' && this.isCreator;
        return this.rawStatus === 'Draft'; 
    }
    
    get canRecall()  { 
        if (hasCPQStandardUser) return this.rawStatus === 'In Review' && this.isCreator;
        return this.rawStatus === 'In Review'; 
    }
    
    get canApprove() { return this.rawStatus === 'In Review' && !hasCPQStandardUser; }
    get canReject()  { return this.rawStatus === 'In Review' && !hasCPQStandardUser; }

    get totalAmount() {
        if (this.projectedTotals) return this.projectedTotals.totalAmount;
        return this.quote?.Total_Amount__c ?? 0;
    }

    get subtotal() {
        if (this.projectedTotals) return this.projectedTotals.subtotal;
        return this.quote?.Subtotal__c ?? 0;
    }

    get margin() {
        if (this.projectedTotals) {
            return this.projectedTotals.marginPct ? this.projectedTotals.marginPct.toFixed(2) : 0;
        }
        return this.quote?.Margin__c ?? 0;
    }

    get discount() {
        if (this.projectedTotals) {
            return this.projectedTotals.subtotal > 0
                ? ((this.projectedTotals.discount / this.projectedTotals.subtotal) * 100).toFixed(2)
                : 0;
        }
        return this.quote?.Discount__c ?? 0;
    }

    get statusBadgeClass() {
        const map = {
            'Draft':     'slds-badge status-pill-draft',
            'In Review': 'slds-badge status-pill-review',
            'Approved':  'slds-badge status-pill-approved',
            'Rejected':  'slds-badge status-pill-rejected'
        };
        return map[this.rawStatus] || 'slds-badge status-pill-draft';
    }

    /** True when quote is In Review (used for ⚠ icon in breadcrumb) */
    get isPending() { return this.rawStatus === 'In Review'; }

    get marginAmount() {
        return this.quote?.Margin_Amount__c ?? 0;
    }

    get discountAmount() {
        return this.quote?.Discount_Amount__c ?? 0;
    }

    get startDateLabel() {
        // Quote object exposes ExpirationDate; use CreatedDate as start proxy
        const d = this.quote?.CreatedDate;
        return d ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(d)) : 'N/A';
    }

    get endDateLabel() {
        const d = this.quote?.ExpirationDate;
        return d ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(d)) : 'N/A';
    }

    // ── Approval Logic (Consolidated in Parent) ─────────────────────────

    handleSubmitForApproval() {
        this.openModal('Submit for Approval', 'Submit', 'brand', 'submit');
    }

    async handleRecall() {
        this.isLoading = true;
        try {
            await recallQuote({ quoteId: this.quoteId });
            this.showToast('Success', 'Quote recalled to Draft', 'success');
            await this.handleRefresh();
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleApprove() {
        this.openModal('Approve Quote', 'Approve', 'success', 'approve');
    }

    handleReject() {
        this.openModal('Reject Quote', 'Reject', 'destructive', 'reject');
    }

    openModal(title, label, variant, action) {
        this.modalTitle = title;
        this.modalConfirmLabel = label;
        this.modalConfirmVariant = variant;
        this.currentAction = action;
        this.isModalOpen = true;
    }

    handleModalCancel() {
        this.isModalOpen = false;
    }

    async handleModalConfirm(event) {
        const comments = event.detail.comments;
        const quoteId = this.quoteId;

        this.isLoading = true;
        try {
            if (this.currentAction === 'submit') {
                await submitForApproval({ quoteId, comments });
            } else if (this.currentAction === 'approve') {
                await approveQuote({ quoteId, comments });
            } else if (this.currentAction === 'reject') {
                await rejectQuote({ quoteId, comments });
            }
            
            this.showToast('Success', `Quote ${this.currentAction}ed successfully`, 'success');
            this.isModalOpen = false;
            await this.handleRefresh();
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredQuoteResult);
            // Notify child tabs to refresh their wires
            this.template.querySelector('c-quote-summary-tab')?.refreshAuditTrail();
            this.template.querySelector('c-quote-line-items-tab')?.handleRefresh();
            this.template.querySelector('c-quote-timeline-tab')?.refresh();
        } finally {
            this.isLoading = false;
        }
    }

    // ── General handlers ─────────────────────────────────────────────────

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleQuoteUpdate() {
        // Triggered by quoteSummaryTab if it modifies the quote
        this.handleRefresh();
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

    handleLinesChanged() {
        this.handleRefresh();
    }

    async handleGlobalSave() {
        this.isLoading = true;
        try {
            const lineItemsTab = this.template.querySelector('c-quote-line-items-tab');
            if (lineItemsTab) await lineItemsTab.save();
            this.projectedTotals = undefined;
            await this.handleRefresh();
            this.dispatchEvent(new CustomEvent('globalrefresh'));
        } catch (err) {
            console.error('Error in global save', err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleGlobalRefresh() {
        await this.handleRefresh();
    }

    handleGeneratePDF() {
        this.isPdfModalOpen = true;
    }

    handlePdfModalClose() {
        this.isPdfModalOpen = false;
    }

    handlePdfSaved() {
        this.handleRefresh();
        // optionally refresh the Pdfs Tab explicitly if necessary
    }

    handleTotalsUpdate(event) {
        this.projectedTotals = event.detail;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
