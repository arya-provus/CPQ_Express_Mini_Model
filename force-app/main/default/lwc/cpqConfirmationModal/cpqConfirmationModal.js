import { LightningElement, api } from 'lwc';

export default class CpqConfirmationModal extends LightningElement {
    @api isOpen = false;
    @api title = 'Confirm Action';
    @api message = 'Are you sure you want to proceed?';
    @api confirmLabel = 'Delete';
    @api cancelLabel = 'Cancel';

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}
