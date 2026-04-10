import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';
import getApprovalHistory from '@salesforce/apex/QuoteController.getApprovalHistory';

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const PAST_MONTHS   = 6;
const FUTURE_MONTHS = 18;
const COL_W         = 90;   // must match CSS .gantt-cell min-width

// Bar colours defined in JS so they go into inline style
// (immune to SLDS CSS overrides)
const BAR_COLORS = {
    product: { bg: '#1e40af', border: '#1e3a8a' },
    addon:   { bg: '#5b21b6', border: '#4c1d95' },
    role:    { bg: '#065f46', border: '#064e3b' }
};

export default class QuoteTimelineTab extends LightningElement {
    @api quoteId;
    @api recordId;
    @api quoteRecord;

    @track rawLines        = [];
    @track approvalHistory = [];

    wiredLinesResult;
    _scrolled = false;

    get targetId() {
        return this.quoteId || this.recordId;
    }

    // ── Wire: Line Items ─────────────────────────────────────────────
    @wire(getQuoteLines, { quoteId: '$targetId' })
    wiredLines(result) {
        this.wiredLinesResult = result;
        if (result.data) {
            this.rawLines = result.data;
        } else {
            this.rawLines = [];
        }
    }

    // ── Public refresh — called by parent after lines change ─────────
    @api
    refresh() {
        this._scrolled = false;   // allow re-scroll once fresh data is in
        return refreshApex(this.wiredLinesResult);
    }

    // ── Wire: Approval History ───────────────────────────────────────
    @wire(getApprovalHistory, { quoteId: '$targetId' })
    wiredHistory({ data }) {
        if (data) {
            this.approvalHistory = data.map(h => ({
                ...h,
                userName:      h.Action_By__r ? h.Action_By__r.Name : 'System',
                formattedDate: h.Action_Date__c
                    ? new Intl.DateTimeFormat('en-US', {
                        month: 'short', day: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                      }).format(new Date(h.Action_Date__c))
                    : '',
                iconName:  this._iconForAction(h.Action__c),
                iconClass: `audit-circle audit-${(h.Action__c || '').toLowerCase()}`
            }));
        }
    }

    _iconForAction(a) {
        const m = { Submitted: 'utility:send', Approved: 'utility:check',
                    Rejected: 'utility:close',  Recalled: 'utility:back' };
        return m[a] || 'utility:record';
    }

    // ── Auto-scroll to today on first render ─────────────────────────
    renderedCallback() {
        if (!this._scrolled && this.rawLines.length > 0) {
            const el = this.template.querySelector('.gantt-scroll');
            if (el) {
                el.scrollLeft = Math.max(0, (PAST_MONTHS - 2) * COL_W);
                this._scrolled = true;
            }
        }
    }

    // ── Month window ─────────────────────────────────────────────────
    get ganttMonths() {
        const now = new Date();
        const result = [];
        for (let i = -PAST_MONTHS; i <= FUTURE_MONTHS; i++) {
            const d = new Date(now.getFullYear(), now.getMonth() + i, 1);
            result.push({ year: d.getFullYear(), month: d.getMonth() });
        }
        return result;
    }

    get monthHeaders() {
        const now = new Date();
        return this.ganttMonths.map(m => ({
            key:         `${m.year}-${m.month}`,
            label:       MONTH_LABELS[m.month],
            headerClass: (m.year === now.getFullYear() && m.month === now.getMonth())
                ? 'mcol today-col' : 'mcol'
        }));
    }

    get yearHeaders() {
        const map = {};
        this.ganttMonths.forEach(m => {
            if (!map[m.year]) map[m.year] = 0;
            map[m.year]++;
        });
        return Object.entries(map).map(([y, span]) => ({ year: +y, span }));
    }

    get ganttColSpan()  { return this.ganttMonths.length + 2; }
    get hasGanttData()  { return this.rawLines && this.rawLines.length > 0; }
    get hasHistory()    { return this.approvalHistory && this.approvalHistory.length > 0; }

    // ── Quote fallback dates ──────────────────────────────────────────
    get _quoteStart() {
        const d = this.quoteRecord?.Start_Date__c || this.quoteRecord?.CreatedDate;
        return d ? new Date(d) : null;
    }
    get _quoteEnd() {
        const d = this.quoteRecord?.End_Date__c || this.quoteRecord?.ExpirationDate;
        return d ? new Date(d) : null;
    }

    // ── Phase grouping ────────────────────────────────────────────────
    get ganttPhases() {
        if (!this.rawLines || this.rawLines.length === 0) return [];
        const map = {};
        this.rawLines.forEach(line => {
            const phase = line.Task__c || 'Default Phase';
            if (!map[phase]) map[phase] = [];
            map[phase].push(line);
        });
        return Object.entries(map).map(([name, lines]) => ({
            name,
            items: lines.map(l => this._buildGanttItem(l))
        }));
    }

    // ── Build one Gantt row ───────────────────────────────────────────
    _buildGanttItem(line) {
        const isRole    = !!(line.Resource_Role__c);
        const isAddon   = !isRole && (line.Product2?.Name || '').startsWith('Add-on:');
        const isProduct = !isRole && !isAddon;

        const name = isRole
            ? (line.Resource_Role__r?.Name || 'Role')
            : (line.Product2?.Name || 'Item');

        // Resolve start date — fall back to quote's CreatedDate / Start_Date__c
        const rawStart = line.Start_Date__c
            ? new Date(line.Start_Date__c)
            : this._quoteStart;

        // Resolve end date — fall back to quote, then to start + quantity
        let rawEnd = line.End_Date__c
            ? new Date(line.End_Date__c)
            : this._quoteEnd;

        if (!rawEnd && rawStart && line.Quantity) {
            rawEnd = new Date(
                rawStart.getFullYear(),
                rawStart.getMonth() + Math.round(line.Quantity),
                rawStart.getDate()
            );
        }

        // Pick colours for this type — embedded in inline style to bypass SLDS
        const colorsKey = isRole ? 'role' : isAddon ? 'addon' : 'product';
        const colors    = BAR_COLORS[colorsKey];

        const now = new Date();

        const cells = this.ganttMonths.map(m => {
            const isToday = m.year === now.getFullYear() && m.month === now.getMonth();
            const cellClass = isToday ? 'gantt-cell today-bg' : 'gantt-cell';

            if (!this._spans(rawStart, rawEnd, m.year, m.month)) {
                return { key: `${m.year}-${m.month}`, hasBar: false, cellClass };
            }

            const days         = new Date(m.year, m.month + 1, 0).getDate();
            const isStartMonth = rawStart && rawStart.getFullYear() === m.year && rawStart.getMonth() === m.month;
            const isEndMonth   = rawEnd   && rawEnd.getFullYear()   === m.year && rawEnd.getMonth()   === m.month;

            const leftPct  = isStartMonth ? Math.round(((rawStart.getDate() - 1) / days) * 100) : 0;
            const rightPct = isEndMonth   ? Math.round(((days - rawEnd.getDate())   / days) * 100) : 0;

            const rL = isStartMonth ? '5px' : '0';
            const rR = isEndMonth   ? '5px' : '0';

            // ── Background color in inline style — cannot be overridden by SLDS ──
            const cellBarStyle = [
                `left:${leftPct}%`,
                `right:${rightPct}%`,
                `border-radius:${rL} ${rR} ${rR} ${rL}`,
                `background-color:${colors.bg}`,
                `border-top:3px solid ${colors.border}`,
                `border-bottom:3px solid ${colors.border}`
            ].join(';') + ';';

            return {
                key: `${m.year}-${m.month}`,
                hasBar:    true,
                showLabel: isStartMonth,
                cellClass,
                cellBarStyle
            };
        });

        return {
            id:           line.Id,
            name,
            duration:     this._durationLabel(rawStart, rawEnd, line.Quantity),
            cells,
            barClass:     'gbar',     // no color class needed — color is inline
            barIconName:  isRole ? 'standard:service_resource'
                        : isAddon ? 'standard:waits'
                        : 'standard:product',
            typeDotClass: isRole    ? 'tdot dot-role'
                        : isAddon   ? 'tdot dot-addon'
                        :             'tdot dot-product'
        };
    }

    _spans(start, end, year, month) {
        if (!start) return false;
        const cStart = new Date(year, month, 1);
        const cEnd   = new Date(year, month + 1, 0);
        if (!end) return start.getFullYear() === year && start.getMonth() === month;
        return start <= cEnd && end >= cStart;
    }

    _durationLabel(start, end, qty) {
        if (start && end) {
            const days = Math.ceil((end - start) / 86400000);
            if (days < 14) return `${days} days`;
            const mo = Math.round(days / 30);
            return mo <= 1 ? 'about 1 month' : `about ${mo} months`;
        }
        if (qty) {
            const n = Math.round(qty);
            return n <= 1 ? 'about 1 month' : `about ${n} months`;
        }
        return 'N/A';
    }
}
