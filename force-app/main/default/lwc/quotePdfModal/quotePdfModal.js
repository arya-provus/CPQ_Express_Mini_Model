import { LightningElement, api, track } from 'lwc';
import generateAndSavePdf from '@salesforce/apex/QuoteDocumentService.generateAndSavePdf';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuotePdfModal extends LightningElement {
    @api quoteId;
    @api isOpen = false;

    @track notes = '';
    @track isLoading = false;

    get pdfUrl() {
        return `/apex/QuotePDF?id=${this.quoteId}`;
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    handleClose() {
        this.isOpen = false;
        this.notes = '';
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        this.isLoading = true;
        generateAndSavePdf({ quoteId: this.quoteId, notes: this.notes })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'PDF Generated and Saved Successfully',
                    variant: 'success'
                }));
                this.handleClose();
                this.dispatchEvent(new CustomEvent('pdfsaved'));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error generating PDF',
                    message: error.body?.message || error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleDownload() {
        window.open(this.pdfUrl, '_blank');
    }
}
