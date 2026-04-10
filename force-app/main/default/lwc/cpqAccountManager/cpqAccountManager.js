import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';
import getAccountTypes from '@salesforce/apex/AccountController.getAccountTypes';
import getAccountIndustries from '@salesforce/apex/AccountController.getAccountIndustries';
import deleteAccount from '@salesforce/apex/AccountController.deleteAccount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpqAccountManager extends LightningElement {
    @track searchTerm = '';
    @track typeFilter = '';
    @track industryFilter = '';
    @track accounts = [];
    @track typeOptions = [];
    @track industryOptions = [];

    wiredAccountsResult;
    _searchTimer;

    // ── Wire: Account Types ──────────────────────────────────────────
    @wire(getAccountTypes)
    wiredTypes({ data }) {
        if (data) this.typeOptions = data;
    }

    // ── Wire: Industries ─────────────────────────────────────────────
    @wire(getAccountIndustries)
    wiredIndustries({ data }) {
        if (data) this.industryOptions = data;
    }

    // ── Wire: Accounts ───────────────────────────────────────────────
    @wire(getAccounts, { searchTerm: '$searchTerm', typeFilter: '$typeFilter', industryFilter: '$industryFilter' })
    wiredAccounts(result) {
        this.wiredAccountsResult = result;
        const { data, error } = result;
        if (data) {
            this.accounts = data.map((acc, idx) => ({ ...acc, rowNum: idx + 1 }));
        } else if (error) {
            console.error('Account wire error:', error);
            this.accounts = [];
        }
    }

    // ── Computed ─────────────────────────────────────────────────────
    get hasAccounts() {
        return this.accounts && this.accounts.length > 0;
    }

    get accountCount() {
        return this.accounts ? this.accounts.length : 0;
    }

    // ── Handlers ─────────────────────────────────────────────────────
    handleSearch(event) {
        clearTimeout(this._searchTimer);
        const val = event.target.value;
        // Debounce 300ms
        this._searchTimer = setTimeout(() => {
            this.searchTerm = val;
        }, 300);
    }

    handleTypeFilter(event) {
        this.typeFilter = event.target.value;
    }

    handleIndustryFilter(event) {
        this.industryFilter = event.target.value;
    }

    async handleRefresh() {
        await refreshApex(this.wiredAccountsResult);
    }

    handleNew() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Info',
            message: 'Use Salesforce to create a new Account record.',
            variant: 'info'
        }));
    }

    handleAccountClick(event) {
        const accountId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewaccount', { detail: { accountId } }));
    }

    async handleDelete(event) {
        event.stopPropagation();
        const accountId = event.currentTarget.dataset.id;
        const acc = this.accounts.find(a => a.Id === accountId);
        if (!acc) return;

        // eslint-disable-next-line no-alert
        if (!window.confirm(`Delete account "${acc.Name}"? This cannot be undone.`)) return;

        try {
            await deleteAccount({ accountId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Deleted',
                message: `Account "${acc.Name}" deleted.`,
                variant: 'success'
            }));
            await refreshApex(this.wiredAccountsResult);
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: err.body?.message || 'Delete failed.',
                variant: 'error'
            }));
        }
    }
}
