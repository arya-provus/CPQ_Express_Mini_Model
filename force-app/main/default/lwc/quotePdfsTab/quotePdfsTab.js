import { LightningElement, api, wire, track } from 'lwc';
import getQuoteDocuments from '@salesforce/apex/QuoteDocumentService.getQuoteDocuments';
import deleteQuoteDocument from '@salesforce/apex/QuoteDocumentService.deleteQuoteDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

export default class QuotePdfsTab extends NavigationMixin(LightningElement) {
    @api quoteId;
    @track pdfData = [];
    wiredResult;

    // ── Wire: PDF documents (unchanged) ─────────────────────────────
    @wire(getQuoteDocuments, { quoteId: '$quoteId' })
    wiredDocuments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.pdfData = result.data.map((doc, index) => ({
                ...doc,
                rowNum: String(index + 1),
                versionLabel: 'v' + doc.Version__c,
                createdByName: doc.CreatedBy?.Name || 'System',
                createdRelative: new Date(doc.CreatedDate).toLocaleString(),
                marginLabel: doc.Margin__c ? doc.Margin__c.toFixed(2) + '%' : '0%'
            }));
        } else if (result.error) {
            this.pdfData = [];
            console.error(result.error);
        }
    }

    // ── Enriched data for new HTML template ──────────────────────────
    get enrichedPdfData() {
        if (!this.pdfData || this.pdfData.length === 0) return [];
        const latest = this.pdfData[0]; // first is latest (sorted desc)
        return this.pdfData.map(row => ({
            ...row,
            isLatest: row.Id === latest.Id,
            notesDisplay: row.Notes__c || '-',
            totalFormatted: row.Total_Amount__c != null
                ? '$' + Number(row.Total_Amount__c).toLocaleString('en-US', { minimumFractionDigits: 0 })
                : '-',
            marginAmtFormatted: row.Margin_Amount__c != null
                ? '$' + Number(row.Margin_Amount__c).toLocaleString('en-US', { minimumFractionDigits: 0 })
                : '-'
        }));
    }

    get hasPdfs() {
        return this.pdfData && this.pdfData.length > 0;
    }

    // ── Action Handlers ──────────────────────────────────────────────
    handleView(event) {
        const docId = event.currentTarget.dataset.id;
        const row = this.pdfData.find(r => r.Id === docId);
        if (row?.ContentDocumentId__c) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: {
                    recordIds: row.ContentDocumentId__c,
                    selectedRecordId: row.ContentDocumentId__c
                }
            });
        }
    }

    handleDownload(event) {
        const docId = event.currentTarget.dataset.id;
        const row = this.pdfData.find(r => r.Id === docId);
        if (row?.ContentDocumentId__c) {
            window.open(`/sfc/servlet.shepherd/document/download/${row.ContentDocumentId__c}`, '_blank');
        }
    }

    handleDelete(event) {
        const docId = event.currentTarget.dataset.id;
        deleteQuoteDocument({ documentId: docId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'PDF deleted', variant: 'success' }));
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message, variant: 'error' }));
            });
    }

    // ── Public refresh (called by parent) ────────────────────────────
    @api handleRefresh() {
        if (this.wiredResult) {
            return refreshApex(this.wiredResult);
        }
    }
}
