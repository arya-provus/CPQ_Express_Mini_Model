import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAllRoles from '@salesforce/apex/ResourceRoleController.getAllRoles';
import createRole from '@salesforce/apex/ResourceRoleController.createRole';
import updateRole from '@salesforce/apex/ResourceRoleController.updateRole';
import deleteResourceRoles from '@salesforce/apex/ResourceRoleController.deleteResourceRoles';
import hasCPQStandardUser from '@salesforce/customPermission/CPQ_Standard_User';

const COLUMNS = [
    { label: '#', fieldName: 'index', type: 'number', initialWidth: 50 },
    { 
        label: 'ID', 
        fieldName: 'Id', 
        type: 'button',
        initialWidth: 120,
        typeAttributes: {
            label: { fieldName: 'RoleNumber' },
            name: 'view_role',
            variant: 'base',
            class: 'slds-text-link'
        }
    },
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Location', fieldName: 'LocationText', type: 'text' },
    { label: 'Billing Unit', fieldName: 'BillingUnitText', type: 'text' },
    { label: 'Price', fieldName: 'Base_Rate__c', type: 'currency' },
    { label: 'Cost', fieldName: 'Cost__c', type: 'currency' },
    { label: 'Active', fieldName: 'IsActive__c', type: 'boolean' },
    { label: 'Active', fieldName: 'IsActive__c', type: 'boolean' }
];

export default class ResourceRoleManager extends LightningElement {
    @track roles = [];
    @track searchKey = '';
    @track statusFilter = 'All Status';
    @api isModalMode = false;
    @track columns = [];

    get canManageCatalog() {
        return !hasCPQStandardUser;
    }

    get hideCheckboxColumn() {
        return false;
    }

    @track selectedRows = [];
    @track selectedCount = 0;
    @track isConfirmOpen = false;
    @track confirmTitle = '';
    @track confirmMessage = '';
    pendingDeleteIds = null;

    @track isModalOpen = false;
    @track isFilterOpen = false;
    @track popoverFilters = {
        status: 'All Status',
        usage: 'All Items',
        billingUnit: 'All Billing Units',
        minPrice: null,
        maxPrice: null
    };

    @track roleFields = {
        Id: null,
        Name: '',
        Description: '',
        BaseRate: 0,
        Cost: 0,
        BillingUnit: 'Hour',
        City: '',
        State: '',
        Country: ''
    };

    get modalTitle() {
        return this.roleFields.Id ? 'Edit Resource Role' : 'Create New Resource Role';
    }

    get modalButtonLabel() {
        return this.roleFields.Id ? 'Update Role' : 'Add Item';
    }

    wiredRolesResult;

    connectedCallback() {
        let baseColumns = [...COLUMNS];

        if (this.canManageCatalog) {
            baseColumns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Edit', name: 'edit_role', iconName: 'utility:edit' },
                        { label: 'Delete', name: 'delete_role', iconName: 'utility:delete' }
                    ]
                }
            });
        }
        this.columns = baseColumns;
    }

    billingOptions = [
        { label: 'Hour', value: 'Hour' },
        { label: 'Day', value: 'Day' },
        { label: 'Month', value: 'Month' }
    ];

    statusOptions = [
        { label: 'All Status', value: 'All Status' },
        { label: 'Active', value: 'Active' },
        { label: 'Inactive', value: 'Inactive' }
    ];

    usageOptions = [
        { label: 'All Items', value: 'All Items' }
    ];

    @wire(getAllRoles)
    wiredRoles(result) {
        this.wiredRolesResult = result;
        if (result.data) {
            this.roles = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to fetch roles', 'error');
        }
    }

    get roleCount() {
        return this.formattedRoles.length;
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    get formattedRoles() {
        let filteredRoles = this.roles;
        if (this.searchKey) {
            const key = this.searchKey.toLowerCase();
            filteredRoles = filteredRoles.filter(r => 
                (r.Name && r.Name.toLowerCase().includes(key)) ||
                (r.City__c && r.City__c.toLowerCase().includes(key)) ||
                (r.Id && r.Id.toLowerCase().includes(key))
            );
        }

        if (this.statusFilter !== 'All Status') {
            const isActive = this.statusFilter === 'Active';
            filteredRoles = filteredRoles.filter(r => r.IsActive__c === isActive);
        }

        return filteredRoles.map((r, index) => {
            let location = '';
            if (r.City__c || r.State__c) {
                location = [r.City__c, r.State__c].filter(Boolean).join(', ');
            } else {
                location = '—';
            }
            return {
                ...r,
                index: index + 1,
                RoleNumber: r.Id ? r.Id.substring(0, 8).toUpperCase() : '',
                LocationText: location,
                BillingUnitText: r.Billing_Unit__c || 'Hour',
                Cost__c: r.Cost__c || 0
            };
        });
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleStatusSelect(event) {
        this.statusFilter = event.detail.value;
    }

    toggleFilterPopover() {
        this.isFilterOpen = !this.isFilterOpen;
    }

    handlePopoverFilterChange(event) {
        const filter = event.target.dataset.filter;
        this.popoverFilters = { ...this.popoverFilters, [filter]: event.target.value };
    }

    async handleRefresh() {
        await refreshApex(this.wiredRolesResult);
        this.showToast('Success', 'Roles refreshed', 'success');
    }

    get isSaveDisabled() {
        return !this.roleFields.Name || this.roleFields.BaseRate <= 0 || !this.roleFields.BillingUnit;
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetFields();
    }

    resetFields() {
        this.roleFields = { 
            Id: null,
            Name: '', 
            Description: '',
            BaseRate: 0, 
            Cost: 0,
            BillingUnit: 'Hour',
            City: '',
            State: '',
            Country: ''
        };
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.roleFields = { ...this.roleFields, [field]: event.target.value };
    }

    async handleSaveRole() {
        try {
            const params = {
                name: this.roleFields.Name,
                baseRate: this.roleFields.BaseRate,
                cost: this.roleFields.Cost,
                billingUnit: this.roleFields.BillingUnit,
                city: this.roleFields.City,
                state: this.roleFields.State,
                country: this.roleFields.Country
            };

            if (this.roleFields.Id) {
                params.roleId = this.roleFields.Id;
                await updateRole(params);
                this.showToast('Success', 'Resource role updated', 'success');
            } else {
                await createRole(params);
                this.showToast('Success', 'Resource role created', 'success');
            }
            this.closeModal();
            await refreshApex(this.wiredRolesResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit_role') {
            this.handleEdit(row);
        } else if (actionName === 'delete_role') {
            this.handleDelete(row.Id);
        }
    }

    handleEdit(row) {
        this.roleFields = {
            Id: row.Id,
            Name: row.Name,
            Description: row.Description__c || '',
            BaseRate: row.Base_Rate__c,
            Cost: row.Cost__c || 0,
            BillingUnit: row.Billing_Unit__c || 'Hour',
            City: row.City__c || '',
            State: row.State__c || '',
            Country: row.Country__c || ''
        };
        this.openModal();
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
        this.selectedCount = this.selectedRows.length;
    }

    handleClearSelection() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) datatable.selectedRows = [];
        this.selectedRows = [];
        this.selectedCount = 0;
    }

    handleBulkDelete() {
        const ids = this.selectedRows.map(row => row.Id);
        this.handleDelete(ids);
    }

    handleDelete(ids) {
        const isBulk = Array.isArray(ids);
        this.pendingDeleteIds = isBulk ? ids : [ids];
        const count = this.pendingDeleteIds.length;
        
        this.confirmTitle = isBulk ? `Delete ${count} Roles` : 'Delete Role';
        this.confirmMessage = `Are you sure you want to delete ${count} resource role${count > 1 ? 's' : ''}? This action cannot be undone.`;
        this.isConfirmOpen = true;
    }

    closeConfirm() {
        this.isConfirmOpen = false;
        this.pendingDeleteIds = null;
    }

    async executeDelete() {
        try {
            this.isConfirmOpen = false;
            await deleteResourceRoles({ roleIds: this.pendingDeleteIds });
            this.showToast('Success', 'Resource roles deleted successfully', 'success');
            this.handleClearSelection();
            return refreshApex(this.wiredRolesResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    @api
    getSelectedRows() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            return datatable.getSelectedRows();
        }
        return [];
    }
}
