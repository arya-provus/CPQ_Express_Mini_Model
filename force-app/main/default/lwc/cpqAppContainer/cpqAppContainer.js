import { LightningElement, track, api } from 'lwc';

export default class CpqAppContainer extends LightningElement {
    @api currentPage = 'dashboard';

    get isDashboard() {
        return this.currentPage === 'dashboard';
    }

    get isQuotes() {
        return this.currentPage === 'quotes';
    }

    get isProducts() {
        return this.currentPage === 'products';
    }

    get isAddons() {
        return this.currentPage === 'addons';
    }

    get isResourceRoles() {
        return this.currentPage === 'resourceRoles';
    }

    get isSettings() {
        return this.currentPage === 'settings';
    }

    get isQuoteDetails() {
        return this.currentPage === 'quoteDetails';
    }

    @track currentQuoteId = null;

    handleViewQuote(event) {
        this.currentQuoteId = event.detail.quoteId;
        this.currentPage = 'quoteDetails';
    }

    handleBackToQuotes() {
        this.currentQuoteId = null;
        this.currentPage = 'quotes';
    }

    handleNavigation(event) {
        console.log('Navigation event received:', event.detail.name);
        this.currentPage = event.detail.name;
    }
}
