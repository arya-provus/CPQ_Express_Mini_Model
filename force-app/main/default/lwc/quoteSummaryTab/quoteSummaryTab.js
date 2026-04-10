import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getApprovalHistory from '@salesforce/apex/QuoteController.getApprovalHistory';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';

export default class QuoteSummaryTab extends LightningElement {
    @api quoteRecord;

    @track approvalHistory = [];
    @track rawLines = [];

    wiredHistoryResult;
    wiredLinesResult;

    // ── Wire: Approval History ───────────────────────────────────────
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

    // ── Wire: Quote Line Items (for real revenue calculations) ────────
    @wire(getQuoteLines, { quoteId: '$quoteRecord.Id' })
    wiredLines(result) {
        this.wiredLinesResult = result;
        if (result.data) {
            this.rawLines = result.data;
        } else {
            this.rawLines = [];
        }
    }

    // ── Public refresh method (called by parent) ─────────────────────
    @api
    refreshAuditTrail() {
        refreshApex(this.wiredHistoryResult);
        return refreshApex(this.wiredLinesResult);
    }

    // ── Quote field helpers ──────────────────────────────────────────
    get opportunityName() {
        return this.quoteRecord?.OpportunityName ||
               this.quoteRecord?.Opportunity?.Name || 'N/A';
    }

    get accountName() {
        return this.quoteRecord?.AccountName ||
               this.quoteRecord?.Account__r?.Name || 'N/A';
    }

    get createdByName() {
        return this.quoteRecord?.CreatedByName ||
               this.quoteRecord?.CreatedBy?.Name || 'System';
    }

    get quoteTimePeriod() {
        return this.quoteRecord?.Quote_Time_Period__c || 'Months';
    }

    get formattedCreatedDate() {
        return this.quoteRecord?.CreatedDate
            ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                .format(new Date(this.quoteRecord.CreatedDate))
            : '-';
    }

    get formattedExpirationDate() {
        return this.quoteRecord?.ExpirationDate
            ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                .format(new Date(this.quoteRecord.ExpirationDate))
            : '-';
    }

    // ── Line Item Classification ──────────────────────────────────────
    /**
     * A line is a Resource Role (Labor) if Resource_Role__c is set.
     * A line is an Add-on if the Product name starts with 'Add-on: '.
     * Everything else is a Product.
     */
    _isRole(line) {
        return !!(line.Resource_Role__c);
    }

    _isAddon(line) {
        if (this._isRole(line)) return false;
        const name = line.Product2?.Name || '';
        return name.startsWith('Add-on:');
    }

    _isProduct(line) {
        return !this._isRole(line) && !this._isAddon(line);
    }

    _lineRevenue(line) {
        // Revenue = UnitPrice × Quantity  (after discount is baked into UnitPrice by the service)
        return (line.UnitPrice || 0) * (line.Quantity || 1);
    }

    _lineCost(line) {
        // Cost__c is per-unit; multiply by Quantity
        return (line.Cost__c || 0) * (line.Quantity || 1);
    }

    // ── Labor ─────────────────────────────────────────────────────────
    get laborLines()   { return this.rawLines.filter(l => this._isRole(l)); }
    get laborRevenue() { return this.laborLines.reduce((s, l) => s + this._lineRevenue(l), 0); }
    get laborCost()    { return this.laborLines.reduce((s, l) => s + this._lineCost(l),    0); }
    get laborMargin()  { return this.laborRevenue - this.laborCost; }
    get laborCount()   { return this.laborLines.length; }

    // ── Products ──────────────────────────────────────────────────────
    get productLines()   { return this.rawLines.filter(l => this._isProduct(l)); }
    get productRevenue() { return this.productLines.reduce((s, l) => s + this._lineRevenue(l), 0); }
    get productCost()    { return this.productLines.reduce((s, l) => s + this._lineCost(l),    0); }
    get productMargin()  { return this.productRevenue - this.productCost; }
    get productCount()   { return this.productLines.length; }

    // ── Add-ons ───────────────────────────────────────────────────────
    get addonLines()   { return this.rawLines.filter(l => this._isAddon(l)); }
    get addonRevenue() { return this.addonLines.reduce((s, l) => s + this._lineRevenue(l), 0); }
    get addonCost()    { return this.addonLines.reduce((s, l) => s + this._lineCost(l),    0); }
    get addonMargin()  { return this.addonRevenue - this.addonCost; }
    get addonCount()   { return this.addonLines.length; }

    // ── Quote-level totals (from the Quote record, as the source of truth) ──
    get totalAmount() { return this.quoteRecord?.Total_Amount__c || 0; }
    get totalCost()   { return this.quoteRecord?.Total_Cost__c   || 0; }
    get marginAmount(){ return this.quoteRecord?.Margin_Amount__c || (this.totalAmount - this.totalCost); }

    // ── Formatted strings ────────────────────────────────────────────
    get laborRevenueFormatted()  { return this.fmt(this.laborRevenue); }
    get laborCostFormatted()     { return this.fmt(this.laborCost); }
    get laborMarginFormatted()   { return this.fmt(this.laborMargin); }
    get productRevenueFormatted(){ return this.fmt(this.productRevenue); }
    get productCostFormatted()   { return this.fmt(this.productCost); }
    get productMarginFormatted() { return this.fmt(this.productMargin); }
    get addonRevenueFormatted()  { return this.fmt(this.addonRevenue); }
    get addonCostFormatted()     { return this.fmt(this.addonCost); }
    get addonMarginFormatted()   { return this.fmt(this.addonMargin); }

    // ── Trend badges (margin %) ───────────────────────────────────────
    get laborTrend() {
        if (!this.laborRevenue) return '';
        const pct = (this.laborMargin / this.laborRevenue * 100).toFixed(1);
        return (this.laborMargin >= 0 ? '↗ ' : '↘ ') + pct + '%';
    }
    get productTrend() {
        if (!this.productRevenue) return '';
        const pct = (this.productMargin / this.productRevenue * 100).toFixed(1);
        return (this.productMargin >= 0 ? '↗ ' : '↘ ') + pct + '%';
    }
    get addonTrend() {
        if (!this.addonRevenue) return '';
        const pct = (this.addonMargin / this.addonRevenue * 100).toFixed(1);
        return (this.addonMargin >= 0 ? '↗ ' : '↘ ') + pct + '%';
    }

    // ── Bar chart styles ─────────────────────────────────────────────
    get chartMax() {
        return Math.max(this.laborRevenue, this.productRevenue, this.addonRevenue, this.totalCost, 1);
    }

    get laborCostBarStyle()    { return this.barStyle(this.laborCost);    }
    get laborMarginBarStyle()  { return this.barStyle(this.laborMargin);  }
    get productCostBarStyle()  { return this.barStyle(this.productCost);  }
    get productMarginBarStyle(){ return this.barStyle(this.productMargin);}
    get addonCostBarStyle()    { return this.barStyle(this.addonCost);    }
    get addonMarginBarStyle()  { return this.barStyle(this.addonMargin);  }

    barStyle(value) {
        const pct = this.chartMax > 0 ? Math.max(0, (value / this.chartMax) * 100) : 0;
        return `height: ${Math.min(pct, 100)}%;`;
    }

    // ── Phase breakdown table ────────────────────────────────────────
    get phaseTableData() {
        // Group lines by Task__c phase; fall back to 'Default'
        const phaseMap = {};
        this.rawLines.forEach(line => {
            const phase = line.Task__c || 'Default';
            if (!phaseMap[phase]) {
                phaseMap[phase] = { labor: 0, product: 0, addon: 0, total: 0, items: 0 };
            }
            const rev = this._lineRevenue(line);
            phaseMap[phase].total += rev;
            phaseMap[phase].items += 1;
            if (this._isRole(line))    phaseMap[phase].labor   += rev;
            else if (this._isAddon(line)) phaseMap[phase].addon += rev;
            else                       phaseMap[phase].product += rev;
        });

        if (Object.keys(phaseMap).length === 0) {
            return [{
                phase: 'Default',
                laborFormatted:   this.fmt(0),
                productFormatted: this.fmt(0),
                addonFormatted:   this.fmt(0),
                totalFormatted:   this.fmt(0),
                items: 0
            }];
        }

        return Object.entries(phaseMap).map(([phase, vals]) => ({
            phase,
            laborFormatted:   this.fmt(vals.labor),
            productFormatted: this.fmt(vals.product),
            addonFormatted:   this.fmt(vals.addon),
            totalFormatted:   this.fmt(vals.total),
            items: vals.items
        }));
    }

    get phaseChartData() {
        return this.phaseTableData.map(row => ({
            name: row.phase,
            costBarStyle:   this.barStyle(this.totalCost / (this.phaseTableData.length || 1)),
            marginBarStyle: this.barStyle(this.marginAmount / (this.phaseTableData.length || 1))
        }));
    }

    get hasPhaseData() {
        return this.rawLines && this.rawLines.length > 0;
    }

    get hasApprovalHistory() {
        return this.approvalHistory && this.approvalHistory.length > 0;
    }

    // ── Helpers ──────────────────────────────────────────────────────
    fmt(value) {
        const n = value || 0;
        return '$' + Number(n).toLocaleString('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    getRelativeTime(dateString) {
        if (!dateString) return '';
        const diff = Date.now() - new Date(dateString).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'just now';
        if (mins < 60) return `${mins} mins ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs} hrs ago`;
        const days = Math.floor(hrs / 24);
        return `${days} days ago`;
    }
}
