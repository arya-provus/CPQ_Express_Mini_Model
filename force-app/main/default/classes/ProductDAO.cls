public with sharing class ProductDAO {
    
    /**
     * Gets the ID of the Standard Pricebook.
     * @return The standard pricebook ID.
     */
    public Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    }

    /**
     * Inserts a Product2 record.
     * @param p The Product2 record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult insertProduct(Product2 p) {
        return Database.insert(p, true);
    }

    /**
     * Inserts a PricebookEntry record.
     * @param pbe The PricebookEntry record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult insertPricebookEntry(PricebookEntry pbe) {
        return Database.insert(pbe, true);
    }

    /**
     * Updates a Product2 record.
     * @param p The Product2 record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult updateProduct(Product2 p) {
        return Database.update(p, true);
    }

    /**
     * Updates a PricebookEntry record.
     * @param pbe The PricebookEntry record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult updatePricebookEntry(PricebookEntry pbe) {
        return Database.update(pbe, true);
    }

    /**
     * Queries active products with their standard unit prices.
     * @return List of PricebookEntry records.
     */
    public List<PricebookEntry> getActivePricebookEntries() {
        return [
            SELECT Id, Product2Id, Product2.Name, Product2.Description, Product2.QuantityUnitOfMeasure, UnitPrice, IsActive 
            FROM PricebookEntry 
            WHERE IsActive = true 
            AND Pricebook2.IsStandard = true
            ORDER BY Product2.Name ASC
        ];
    }
    /**
     * Deletes a Product2 and its associated PricebookEntries.
     * @param productId The product ID to delete.
     */
    public void deleteProduct(Id productId) {
        // Find all pricebook entries first to delete them
        List<PricebookEntry> entries = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId];
        delete entries;
        
        // Delete the product itself
        Product2 prod = new Product2(Id = productId);
        delete prod;
    }

    /**
     * Deletes multiple Product2 records.
     * @param productIds List of Product IDs to delete.
     */
    public void deleteProducts(List<Id> productIds) {
        if (productIds != null && !productIds.isEmpty()) {
            List<PricebookEntry> entries = [SELECT Id FROM PricebookEntry WHERE Product2Id IN :productIds];
            delete entries;
            delete [SELECT Id FROM Product2 WHERE Id IN :productIds];
        }
    }
}
