import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// Cache bust: v2

export default class CpqSidebar extends NavigationMixin(LightningElement) {
    /**
     * Determines which menu item is highlighted.
     * Pass this from the Lightning App Builder for each page.
     */
    @api activeItem = 'dashboard';

    @track menuItems = [
        { name: 'dashboard', label: 'Dashboard', icon: 'utility:apps', target: 'standard__navItemPage', targetApiName: 'CPQ_Home' },
        { name: 'quotes', label: 'Quotes', icon: 'utility:quote', target: 'standard__navItemPage', targetApiName: 'CPQ_Quotes' },
        { name: 'accounts', label: 'Accounts', icon: 'utility:people', target: 'standard__objectPage', objectApiName: 'Account', actionName: 'list' },
        { name: 'resourceRoles', label: 'Resource Roles', icon: 'utility:groups', target: 'standard__navItemPage', targetApiName: 'CPQ_Resource_Roles' },
        { name: 'products', label: 'Products', icon: 'utility:product_transfer', target: 'standard__navItemPage', targetApiName: 'CPQ_Products' },
        { name: 'addons', label: 'Add-ons', icon: 'utility:puzzle', target: 'standard__navItemPage', targetApiName: 'CPQ_Add_Ons' },
        { name: 'aiAssistant', label: 'AI Assistant', icon: 'utility:magicwand', target: 'standard__navItemPage', targetApiName: 'CPQ_AI_Assistant' }
    ];

    @track bottomItems = [
        { name: 'feedback', label: 'Feedback', icon: 'utility:smiley_and_people', target: 'link' },
        { name: 'tour', label: 'Take a Tour', icon: 'utility:play', target: 'link' },
        { name: 'settings', label: 'Settings', icon: 'utility:settings', target: 'link' }
    ];

    get menuItemsWithState() {
        return this.menuItems.map(item => ({
            ...item,
            className: `nav-item ${this.activeItem === item.name ? 'nav-item-active' : ''}`,
            iconVariant: this.activeItem === item.name ? 'inverse' : ''
        }));
    }

    handleItemClick(event) {
        event.preventDefault();
        const name = event.currentTarget.dataset.name;
        const item = this.menuItems.find(i => i.name === name) || this.bottomItems.find(i => i.name === name);

        if (!item) return;

        // Navigate using Salesforce Navigation Engine
        if (item.target === 'standard__navItemPage') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: item.targetApiName
                }
            });
        } else if (item.target === 'standard__namedPage') {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: item.targetApiName
                }
            });
        } else if (item.target === 'standard__objectPage') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: item.objectApiName,
                    actionName: item.actionName
                }
            });
        } else if (item.target === 'link' && item.name === 'settings') {
            // Internal application navigation for Settings
            this.dispatchEvent(new CustomEvent('navselect', {
                detail: { name: 'settings' }
            }));
        }
    }
}
