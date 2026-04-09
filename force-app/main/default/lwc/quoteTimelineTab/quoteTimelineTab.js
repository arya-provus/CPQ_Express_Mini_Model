import { LightningElement, api, track, wire } from 'lwc';
import getQuoteLines from '@salesforce/apex/QuoteLineController.getQuoteLines';
import getApprovalHistory from '@salesforce/apex/QuoteController.getApprovalHistory';

export default class QuoteTimelineTab extends LightningElement {
    @api quoteId;
    @api recordId;
    @track timelineData = [];
    @track approvalHistory = [];

    get targetId() {
        return this.quoteId || this.recordId;
    }

    @wire(getQuoteLines, { quoteId: '$targetId' })
    wiredLines({ error, data }) {
        if (data) {
            this.timelineData = data.map((line, index) => {
                let name = line.Resource_Role__c ? line.Resource_Role__r.Name : (line.Product2 ? line.Product2.Name : 'System Item');
                return {
                    id: line.Id,
                    name: name,
                    startDate: line.Start_Date__c || 'N/A',
                    endDate: line.End_Date__c || 'N/A',
                    style: `width: ${Math.max(10, (line.Quantity || 1) * 10)}%; background-color: ` + (index % 2 === 0 ? '#3b82f6' : '#10b981')
                };
            });
        }
    }

    @wire(getApprovalHistory, { quoteId: '$targetId' })
    wiredHistory({ error, data }) {
        if (data) {
            this.approvalHistory = data.map(item => ({
                ...item,
                userName: item.Action_By__r ? item.Action_By__r.Name : 'System',
                formattedDate: new Intl.DateTimeFormat('en-US', { 
                    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' 
                }).format(new Date(item.Action_Date__c)),
                isSubmit: item.Action__c === 'Submitted',
                isApprove: item.Action__c === 'Approved',
                isReject: item.Action__c === 'Rejected',
                isRecall: item.Action__c === 'Recalled',
                iconName: this.getIconForAction(item.Action__c),
                iconClass: `timeline-icon ${item.Action__c.toLowerCase()}`
            }));
        }
    }

    getIconForAction(action) {
        switch (action) {
            case 'Submitted': return 'utility:send';
            case 'Approved': return 'utility:check';
            case 'Rejected': return 'utility:close';
            case 'Recalled': return 'utility:back';
            default: return 'utility:record';
        }
    }

    get hasHistory() {
        return this.approvalHistory && this.approvalHistory.length > 0;
    }
}
