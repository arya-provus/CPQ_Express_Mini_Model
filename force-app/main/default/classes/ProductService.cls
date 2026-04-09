public with sharing class ProductService {
    private static ProductDAO dao = new ProductDAO();

    /**
     * Creates a product and its standard pricebook entry with extra metadata.
     */
    public Id createProduct(String name, Decimal price, Boolean isActive, String description, Decimal cost, String billingUnit) {
        if (String.isBlank(name)) {
            throw new IllegalArgumentException('Product name is required.');
        }
        if (price == null || price < 0) {
            throw new IllegalArgumentException('A valid positive price is required.');
        }

        // 1. Create Product2
        Product2 newProduct = new Product2(
            Name = name,
            IsActive = isActive,
            Description = description,
            QuantityUnitOfMeasure = billingUnit
        );

        // Safe way to add Cost__c if it exists, otherwise skip (to avoid deployment failure)
        try {
            newProduct.put('Cost__c', cost);
        } catch(Exception e) {
            // Cost__c field likely missing, skipping for now
        }

        Database.SaveResult productResult = dao.insertProduct(newProduct);
        
        if (!productResult.isSuccess()) {
            throw new AuraHandledException('Error creating product: ' + getErrors(productResult));
        }

        Id productId = productResult.getId();

        // 2. Create PricebookEntry for Standard Pricebook
        Id standardPricebookId = dao.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = productId,
            UnitPrice = price,
            IsActive = isActive
        );
        Database.SaveResult pbeResult = dao.insertPricebookEntry(pbe);

        if (!pbeResult.isSuccess()) {
            throw new AuraHandledException('Error creating pricebook entry: ' + getErrors(pbeResult));
        }

        return productId;
    }

    /**
     * Updates an existing product and its standard pricebook entry.
     */
    public void updateProduct(Id productId, String name, Decimal price, Boolean isActive, String description, Decimal cost, String billingUnit) {
        if (productId == null) {
            throw new IllegalArgumentException('Product Id is required for updates.');
        }

        // 1. Update Product2
        Product2 prod = new Product2(
            Id = productId,
            Name = name,
            IsActive = isActive,
            Description = description,
            QuantityUnitOfMeasure = billingUnit
        );

        try {
            prod.put('Cost__c', cost);
        } catch(Exception e) { }

        Database.SaveResult productResult = dao.updateProduct(prod);
        if (!productResult.isSuccess()) {
            throw new AuraHandledException('Error updating product: ' + getErrors(productResult));
        }

        // 2. Update PricebookEntry
        Id standardPricebookId = dao.getStandardPricebookId();
        List<PricebookEntry> entries = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :standardPricebookId LIMIT 1];
        
        if (!entries.isEmpty()) {
            PricebookEntry pbe = new PricebookEntry(
                Id = entries[0].Id,
                UnitPrice = price,
                IsActive = isActive
            );
            Database.SaveResult pbeResult = dao.updatePricebookEntry(pbe);
            if (!pbeResult.isSuccess()) {
                throw new AuraHandledException('Error updating pricebook entry: ' + getErrors(pbeResult));
            }
        }
    }

    /**
     * Fetches active products with their prices.
     */
    public List<PricebookEntry> getActiveProducts() {
        return dao.getActivePricebookEntries();
    }

    /**
     * Deletes a product by its ID.
     * @param productId The ID to delete.
     */
    public void deleteProduct(Id productId) {
        if (productId == null) {
            throw new IllegalArgumentException('Product Id is required.');
        }
        dao.deleteProduct(productId);
    }

    /**
     * Deletes multiple products.
     */
    public void deleteProducts(List<Id> productIds) {
        dao.deleteProducts(productIds);
    }

    private String getErrors(Database.SaveResult result) {
        String errors = '';
        for (Database.Error err : result.getErrors()) {
            errors += err.getMessage() + ' ';
        }
        return errors;
    }
}
