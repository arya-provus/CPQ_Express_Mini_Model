import { LightningElement, track, wire } from 'lwc';
import getTeamMembers from '@salesforce/apex/TeamManagerController.getTeamMembers';
import createTeamMember from '@salesforce/apex/TeamManagerController.createTeamMember';
import deactivateUser from '@salesforce/apex/TeamManagerController.deactivateUser';
import canManageUsers from '@salesforce/apex/TeamManagerController.canManageUsers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class CpqUserManager extends LightningElement {
    @track users = [];
    @track isPanelOpen = false;
    @track canManage = false;
    wiredUsersResult;
    
    @track form = {
        firstName: '',
        lastName: '',
        email: '',
        username: '',
        role: ''
    };

    @wire(canManageUsers)
    wiredCanManage({ error, data }) {
        if (data !== undefined) {
            this.canManage = data;
        } else if (error) {
            console.error('Error fetching manage users permission', error);
        }
    }

    @wire(getTeamMembers)
    wiredUsers(result) {
        this.wiredUsersResult = result;
        if (result.data) {
            this.users = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to fetch users. Check Profile dependencies.', 'error');
        }
    }

    get usersView() {
        return this.users.map(u => {
            let roleClass = 'role-pill';
            let avatarClass = 'avatar';
            if(u.role === 'Admin' || u.role === 'System Administrator') { roleClass += ' admin-pill'; avatarClass += ' avatar-admin'; }
            else if(u.role === 'Manager') { roleClass += ' manager-pill'; avatarClass += ' avatar-manager'; }
            else { roleClass += ' user-pill'; avatarClass += ' avatar-user'; }
            
            return {
                ...u,
                roleClass,
                avatarClass,
                role: u.role === 'System Administrator' ? 'Admin' : u.role,
                statusText: u.isActive ? 'Active' : 'Inactive',
                statusDotClass: u.isActive ? 'status-dot active' : 'status-dot inactive',
                lastActiveFormatted: u.lastLogin ? new Date(u.lastLogin).toLocaleDateString() : 'Never'
            };
        });
    }

    get totalSeats() { return 20; }
    get usedSeats() { return this.users.filter(u => u.isActive).length; }
    get availableSeats() { return this.totalSeats - this.usedSeats; }

    get isAdmin() { return this.form.role === 'Admin'; }
    get isManager() { return this.form.role === 'Manager'; }
    get isUserRole() { return this.form.role === 'User'; }

    get adminCardClass() { return `role-card ${this.isAdmin ? 'selected' : ''}`; }
    get managerCardClass() { return `role-card ${this.isManager ? 'selected' : ''}`; }
    get userCardClass() { return `role-card ${this.isUserRole ? 'selected' : ''}`; }

    openPanel() { this.isPanelOpen = true; }
    closePanel() { 
        this.isPanelOpen = false;
        this.resetForm();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.form[field] = event.target.value;
        if(field === 'email') {
            this.form.username = event.target.value;
        }
    }

    selectRole(event) {
        this.form.role = event.currentTarget.dataset.role;
    }

    async handleCreateUser() {
        if(!this.form.firstName || !this.form.lastName || !this.form.email || !this.form.username || !this.form.role) {
            this.showToast('Error', 'Please fill all required fields.', 'error');
            return;
        }

        try {
            await createTeamMember({
                firstName: this.form.firstName,
                lastName: this.form.lastName,
                email: this.form.email,
                username: this.form.username,
                roleName: this.form.role
            });
            this.showToast('Success', 'Team member created!', 'success');
            await refreshApex(this.wiredUsersResult);
            this.closePanel();
        } catch(err) {
            this.showToast('Error', err.body ? err.body.message : err.message, 'error');
        }
    }

    async handleRemoveAccess(event) {
        const id = event.currentTarget.dataset.id;
        await this.deactivate(id);
    }

    async handleDeactivate(event) {
        const id = event.currentTarget.dataset.id;
        await this.deactivate(id);
    }

    async deactivate(id) {
        try {
            await deactivateUser({ userId: id });
            this.showToast('Success', 'User access removed.', 'success');
            await refreshApex(this.wiredUsersResult);
        } catch (err) {
            this.showToast('Error', err.body ? err.body.message : err.message, 'error');
        }
    }

    resetForm() {
        this.form = { firstName: '', lastName: '', email: '', username: '', role: '' };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}