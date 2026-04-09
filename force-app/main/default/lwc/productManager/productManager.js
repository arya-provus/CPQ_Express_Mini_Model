import { LightningElement, wire, track, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasCPQStandardUser from '@salesforce/customPermission/CPQ_Standard_User';
import getActiveProducts from '@salesforce/apex/ProductController.getActiveProducts';
import createProduct from '@salesforce/apex/ProductController.createProduct';
import updateProduct from '@salesforce/apex/ProductController.updateProduct';
import deleteProducts from '@salesforce/apex/ProductController.deleteProducts';

export default class ProductManager extends LightningElement {
    @track products = [];
    @api isModalMode = false;

    get hideCheckboxColumn() {
        return false; // Enable checkboxes for bulk delete
    }

    @track selectedRows = [];
    @track selectedCount = 0;
    @track isConfirmOpen = false;
    @track confirmTitle = '';
    @track confirmMessage = '';
    pendingDeleteIds = null;

    @track isModalOpen = false;
    @track prodFields = {
        Id: null,
        Name: '',
        Description: '',
        Price: 0,
        Cost: 0,
        BillingUnit: 'Each',
        IsActive: true
    };

    columns = [];
    wiredProductsResult;

    get canManageCatalog() {
        return !hasCPQStandardUser;
    }

    billingOptions = [
        { label: 'Each', value: 'Each' },
        { label: 'Monthly', value: 'Monthly' },
        { label: 'Yearly', value: 'Yearly' }
    ];

    connectedCallback() {
        const baseColumns = [
            { label: 'Name', fieldName: 'ProductName', type: 'text' },
            { label: 'Description', fieldName: 'Description', type: 'text' },
            { label: 'Price', fieldName: 'UnitPrice', type: 'currency' },
            { label: 'Billing Unit', fieldName: 'BillingUnit', type: 'text' },
            { label: 'Active', fieldName: 'IsActive', type: 'boolean' }
        ];

        if (this.canManageCatalog) {
            baseColumns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Edit', name: 'edit_product', iconName: 'utility:edit' },
                        { label: 'Delete', name: 'delete_product', iconName: 'utility:delete' }
                    ]
                }
            });
        }
        this.columns = baseColumns;
    }

    @wire(getActiveProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        if (result.data) {
            this.products = result.data.map(pbe => ({
                Id: pbe.Product2Id,
                ProductName: pbe.Product2.Name,
                Description: pbe.Product2.Description,
                UnitPrice: pbe.UnitPrice,
                BillingUnit: pbe.Product2.QuantityUnitOfMeasure,
                IsActive: pbe.IsActive
            }));
        }
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    get isSelectionActive() {
        return this.selectedCount > 0;
    }

    get productCount() {
        return this.products.length;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        // In a real app, you might filter locally or call the server
    }

    async handleRefresh() {
        await refreshApex(this.wiredProductsResult);
        this.showToast('Success', 'Products refreshed', 'success');
    }

    get modalTitle() {
        return this.prodFields.Id ? 'Edit Product' : 'Create New Product';
    }

    get modalButtonLabel() {
        return this.prodFields.Id ? 'Update Product' : 'Add Item';
    }

    get isSaveDisabled() {
        return !this.prodFields.Name || this.prodFields.Price <= 0;
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetFields();
    }

    resetFields() {
        this.prodFields = {
            Id: null,
            Name: '',
            Description: '',
            Price: 0,
            Cost: 0,
            BillingUnit: 'Each',
            IsActive: true
        };
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' || event.target.type === 'toggle' ? event.target.checked : event.target.value;
        this.prodFields = { ...this.prodFields, [field]: value };
    }

    async handleSaveProduct() {
        try {
            if (this.prodFields.Id) {
                // Update
                await updateProduct({
                    productId: this.prodFields.Id,
                    name: this.prodFields.Name,
                    price: this.prodFields.Price,
                    isActive: this.prodFields.IsActive,
                    description: this.prodFields.Description,
                    cost: this.prodFields.Cost,
                    billingUnit: this.prodFields.BillingUnit
                });
                this.showToast('Success', 'Product updated successfully', 'success');
            } else {
                // Create
                await createProduct({
                    name: this.prodFields.Name,
                    price: this.prodFields.Price,
                    isActive: this.prodFields.IsActive,
                    description: this.prodFields.Description,
                    cost: this.prodFields.Cost,
                    billingUnit: this.prodFields.BillingUnit
                });
                this.showToast('Success', 'Product created successfully', 'success');
            }

            this.closeModal();
            return refreshApex(this.wiredProductsResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit_product') {
            this.handleEdit(row);
        } else if (actionName === 'delete_product') {
            this.handleDelete(row.Id);
        }
    }

    handleEdit(row) {
        // Find price info by looking back at the wired result data if needed
        // but row should have flattened structure from wiredProducts mapping
        this.prodFields = {
            Id: row.Id,
            Name: row.ProductName,
            Description: row.Description,
            Price: row.UnitPrice,
            Cost: row.Cost__c || 0, // Need to ensure it was mapped in wiredProducts if available
            BillingUnit: row.BillingUnit,
            IsActive: row.IsActive
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
        
        this.confirmTitle = isBulk ? `Delete ${count} Products` : 'Delete Product';
        this.confirmMessage = `Are you sure you want to delete ${count} product${count > 1 ? 's' : ''}? This action cannot be undone.`;
        this.isConfirmOpen = true;
    }

    closeConfirm() {
        this.isConfirmOpen = false;
        this.pendingDeleteIds = null;
    }

    async executeDelete() {
        try {
            this.isConfirmOpen = false;
            await deleteProducts({ productIds: this.pendingDeleteIds });
            this.showToast('Success', 'Products deleted successfully', 'success');
            this.handleClearSelection();
            return refreshApex(this.wiredProductsResult);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
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
