import { LightningElement, api, track } from 'lwc';

export default class QuoteActionModal extends LightningElement {
    @api isOpen = false;
    @api title = 'Approval Action';
    @api confirmLabel = 'Submit';
    @api confirmVariant = 'brand';

    @track comments = '';

    get isConfirmDisabled() {
        return !this.comments || this.comments.trim().length === 0;
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    handleCancel() {
        this.comments = '';
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm', {
            detail: { comments: this.comments }
        }));
        this.comments = '';
    }
}
