import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAllAddOns from '@salesforce/apex/AddOnController.getAllAddOns';
import createAddOn from '@salesforce/apex/AddOnController.createAddOn';
import updateAddOn from '@salesforce/apex/AddOnController.updateAddOn';
import deleteAddOn from '@salesforce/apex/AddOnController.deleteAddOn';
import deleteAddOns from '@salesforce/apex/AddOnController.deleteAddOns';
import hasCPQStandardUser from '@salesforce/customPermission/CPQ_Standard_User';

const COLUMNS = [
    { label: '#', fieldName: 'index', type: 'number', initialWidth: 50 },
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Description', fieldName: 'Description__c', type: 'text' },
    { label: 'Price', fieldName: 'Price__c', type: 'currency' },
    { label: 'Cost', fieldName: 'Cost__c', type: 'currency' },
    { label: 'Unit', fieldName: 'BillingUnit__c', type: 'text' },
    { label: 'Active', fieldName: 'IsActive__c', type: 'boolean' }
];

export default class AddOnManager extends LightningElement {
    @track addons = [];
    @track searchKey = '';
    @track isModalOpen = false;
    @api isModalMode = false;
    @track columns = [];

    connectedCallback() {
        let baseColumns = [...COLUMNS];
        if (this.canManageCatalog) {
            baseColumns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Edit', name: 'edit_addon', iconName: 'utility:edit' },
                        { label: 'Delete', name: 'delete_addon', iconName: 'utility:delete' }
                    ]
                }
            });
        }
        this.columns = baseColumns;
    }

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

    @track addonFields = {
        Id: null,
        Name: '',
        Description: '',
        Price: 0,
        Cost: 0,
        BillingUnit: 'Each',
        Tags: '',
        IsActive: true
    };

    get modalTitle() {
        return this.addonFields.Id ? 'Edit Add-On' : 'Create New Add-On';
    }

    get modalButtonLabel() {
        return this.addonFields.Id ? 'Update Add-On' : 'Add Item';
    }

    wiredAddOnsResult;

    billingOptions = [
        { label: 'Each', value: 'Each' },
        { label: 'Hour', value: 'Hour' }
    ];

    @wire(getAllAddOns)
    wiredAddOns(result) {
        this.wiredAddOnsResult = result;
        if (result.data) {
            this.addons = result.data.map((a, index) => {
                return {
                    ...a,
                    index: index + 1,
                    AddonNumber: a.Id ? a.Id.substring(0, 8).toUpperCase() : '',
                    Cost__c: a.Cost__c || 0,
                    Tags__c: a.Tags__c || '—'
                };
            });
        } else if (result.error) {
            this.showToast('Error', 'Failed to fetch add-ons', 'error');
        }
    }

    get addonCount() {
        return this.addons.length;
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    async handleRefresh() {
        await refreshApex(this.wiredAddOnsResult);
        this.showToast('Success', 'Add-Ons refreshed', 'success');
    }

    get isSaveDisabled() {
        return this.addonFields.Price < 0 || !this.addonFields.BillingUnit;
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetFields();
    }

    resetFields() {
        this.addonFields = { Id: null, Name: '', Description: '', Price: 0, Cost: 0, BillingUnit: 'Each', Tags: '', IsActive: true };
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.addonFields = { ...this.addonFields, [field]: event.target.value };
    }

    handleToggleChange(event) {
        this.addonFields.IsActive = event.target.checked;
    }

    async handleSaveAddOn() {
        try {
            if (this.addonFields.Id) {
                await updateAddOn({
                    addonId: this.addonFields.Id,
                    name: this.addonFields.Name,
                    price: this.addonFields.Price,
                    description: this.addonFields.Description
                });
                this.showToast('Success', 'Add-On updated', 'success');
            } else {
                await createAddOn({
                    name: this.addonFields.Name,
                    price: this.addonFields.Price,
                    description: this.addonFields.Description
                });
                this.showToast('Success', 'Add-On created', 'success');
            }
            this.closeModal();
            await refreshApex(this.wiredAddOnsResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit_addon') {
            this.handleEdit(row);
        } else if (actionName === 'delete_addon') {
            this.handleDelete(row.Id);
        }
    }

    handleEdit(row) {
        this.addonFields = {
            Id: row.Id,
            Name: row.Name,
            Description: row.Description__c,
            Price: row.Price__c,
            Cost: row.Cost__c || 0,
            BillingUnit: row.BillingUnit__c || 'Each',
            IsActive: row.IsActive__c
        };
        this.openModal();
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
        this.selectedCount = this.selectedRows.length;
    }

    handleClearSelection() {
        this.template.querySelector('lightning-datatable').selectedRows = [];
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
        
        this.confirmTitle = isBulk ? `Delete ${count} Add-Ons` : 'Delete Add-On';
        this.confirmMessage = `Are you sure you want to delete ${count} add-on${count > 1 ? 's' : ''}? This action cannot be undone.`;
        this.isConfirmOpen = true;
    }

    closeConfirm() {
        this.isConfirmOpen = false;
        this.pendingDeleteIds = null;
    }

    async executeDelete() {
        try {
            this.isConfirmOpen = false;
            await deleteAddOns({ addonIds: this.pendingDeleteIds });
            this.showToast('Success', 'Add-Ons deleted successfully', 'success');
            this.handleClearSelection();
            return refreshApex(this.wiredAddOnsResult);
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
