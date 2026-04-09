import { LightningElement, track } from 'lwc';

export default class CpqSettings extends LightningElement {
    @track currentView = 'general';

    @track navItems = [
        { id: 'general', label: 'General', icon: 'utility:settings', className: 'nav-item active' },
        { id: 'company', label: 'Company Info', icon: 'utility:company', className: 'nav-item' },
        { id: 'pdf', label: 'PDF', icon: 'utility:page', className: 'nav-item' },
        { id: 'integrations', label: 'Integrations', icon: 'utility:link', className: 'nav-item' },
        { id: 'users', label: 'Users', icon: 'utility:people', className: 'nav-item' }
    ];

    get isGeneral() {
        return this.currentView === 'general';
    }

    get isUsers() {
        return this.currentView === 'users';
    }

    get isOther() {
        return !this.isGeneral && !this.isUsers;
    }

    handleNavClick(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.currentView = selectedId;

        // Update active class
        this.navItems = this.navItems.map(item => {
            return {
                ...item,
                className: item.id === selectedId ? 'nav-item active' : 'nav-item'
            };
        });
    }

    handleBack() {
        // Dispatch to parent if needed
        this.dispatchEvent(new CustomEvent('navselect', {
            detail: { name: 'dashboard' }
        }));
    }
}