public with sharing class ProductController {

    /**
     * Entry point for LWC to create a Product with a standard unit price and extra details.
     */
    @AuraEnabled
    public static Id createProduct(String name, Decimal price, Boolean isActive, String description, Decimal cost, String billingUnit) {
        try {
            ProductService service = new ProductService();
            return service.createProduct(name, price, isActive, description, cost, billingUnit);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to update an existing product.
     */
    @AuraEnabled
    public static void updateProduct(Id productId, String name, Decimal price, Boolean isActive, String description, Decimal cost, String billingUnit) {
        try {
            ProductService service = new ProductService();
            service.updateProduct(productId, name, price, isActive, description, cost, billingUnit);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to fetch active products and their prices.
     */
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getActiveProducts() {
        try {
            ProductService service = new ProductService();
            return service.getActiveProducts();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Deletes a product.
     */
    @AuraEnabled
    public static void deleteProduct(Id productId) {
        try {
            ProductService service = new ProductService();
            service.deleteProduct(productId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Deletes multiple products by ID.
     */
    @AuraEnabled
    public static void deleteProducts(List<Id> productIds) {
        try {
            ProductService service = new ProductService();
            service.deleteProducts(productIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
