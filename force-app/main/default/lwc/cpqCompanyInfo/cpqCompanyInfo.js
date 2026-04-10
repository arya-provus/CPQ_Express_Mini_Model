import { LightningElement, track, wire } from 'lwc';
import getCompanySettings from '@salesforce/apex/CompanySettingsController.getCompanySettings';
import saveCompanySettings from '@salesforce/apex/CompanySettingsController.saveCompanySettings';
import updateLogoVisibility from '@salesforce/apex/CompanySettingsController.updateLogoVisibility';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpqCompanyInfo extends LightningElement {
    @track isLoading = true;
    @track isAdmin = false;
    @track currentUserId;
    @track settings = {};
    @track originalSettings = {};

    acceptedFormats = ['.png', '.jpg', '.jpeg'];

    connectedCallback() {
        this.loadSettings();
    }

    loadSettings() {
        this.isLoading = true;
        getCompanySettings()
            .then(result => {
                this.isAdmin = result.isAdmin;
                this.currentUserId = result.currentUserId;
                this.settings = { ...result.settings };
                this.originalSettings = { ...result.settings };
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to load settings', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get isNotAdmin() {
        return !this.isAdmin;
    }

    get hasLogo() {
        return !!this.settings.Logo_Document_Id__c;
    }

    get logoUrl() {
        if (this.settings.Logo_Document_Id__c) {
            return `/sfc/servlet.shepherd/document/download/${this.settings.Logo_Document_Id__c}`;
        }
        return '';
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.settings[field] = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            const documentId = uploadedFiles[0].documentId;
            this.settings.Logo_Document_Id__c = documentId;
            
            // Share logo to org
            updateLogoVisibility({ documentId: documentId }).catch(error => console.error(error));
        }
    }

    handleRemoveLogo() {
        this.settings.Logo_Document_Id__c = null;
    }

    handleDiscard() {
        this.settings = { ...this.originalSettings };
    }

    handleSave() {
        this.isLoading = true;
        // Clean proxy object
        const recordToSave = Object.assign({}, this.settings);
        
        saveCompanySettings({ settings: recordToSave })
            .then(() => {
                this.originalSettings = { ...this.settings };
                this.showToast('Success', 'Company information saved successfully.', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to save settings', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
