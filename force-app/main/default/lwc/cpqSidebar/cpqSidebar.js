import { LightningElement, track, api } from 'lwc';

export default class CpqSidebar extends LightningElement {
    @api activeItem = 'dashboard';

    @track menuItems = [
        { name: 'dashboard',     label: 'Dashboard',       icon: 'utility:apps' },
        { name: 'quotes',        label: 'Quotes',           icon: 'utility:quote' },
        { name: 'accounts',      label: 'Accounts',         icon: 'utility:people' },
        { name: 'resourceRoles', label: 'Resource Roles',  icon: 'utility:groups' },
        { name: 'products',      label: 'Products',         icon: 'utility:product_transfer' },
        { name: 'addons',        label: 'Add-ons',          icon: 'utility:puzzle' }
    ];

    @track bottomItems = [
        { name: 'settings', label: 'Settings',    icon: 'utility:settings' }
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
        // All nav items dispatch navselect — cpqAppContainer handles routing
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name },
            bubbles: true,
            composed: true
        }));
    }
}
