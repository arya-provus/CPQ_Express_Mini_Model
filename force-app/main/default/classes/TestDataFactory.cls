@isTest
public class TestDataFactory {
    
    /**
     * Creates a single test Account.
     */
    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    /**
     * Creates a single test Opportunity.
     */
    public static Opportunity createOpportunity(Id accountId, String name) {
        Opportunity opp = new Opportunity(
            AccountId = accountId,
            Name = name,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    /**
     * Creates a single test Quote.
     */
    public static Quote createQuote(Id opportunityId, String name) {
        Id pricebookId = Test.getStandardPricebookId();
        Quote q = new Quote(
            OpportunityId = opportunityId,
            Name = name,
            Pricebook2Id = pricebookId
        );
        insert q;
        return q;
    }

    /**
     * Creates a single test Product2.
     */
    public static Product2 createProduct(String name, Boolean isActive) {
        Product2 p = new Product2(
            Name = name,
            IsActive = isActive
        );
        insert p;
        return p;
    }

    /**
     * Creates a single PricebookEntry in the standard pricebook.
     */
    public static PricebookEntry createStandardPricebookEntry(Id productId, Decimal unitPrice) {
        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = productId,
            UnitPrice = unitPrice,
            IsActive = true
        );
        insert pbe;
        return pbe;
    }
}
