@isTest
private class ProductServiceTest {
    
    @testSetup
    static void setup() {
        // Test setup for products is usually the first step in individual tests or shared here.
    }

    @isTest
    static void testCreateProductPositive() {
        Test.startTest();
        Id productId = ProductController.createProduct('T-Shirt', 25.00, true, 'A test t-shirt', 10.00, 'Each');
        Test.stopTest();

        Assert.isNotNull(productId, 'Product should be created.');
        Product2 p = [SELECT Name, IsActive FROM Product2 WHERE Id = :productId];
        Assert.areEqual('T-Shirt', p.Name);
        Assert.isTrue(p.IsActive);

        PricebookEntry pbe = [SELECT UnitPrice FROM PricebookEntry WHERE Product2Id = :productId LIMIT 1];
        Assert.areEqual(25.00, pbe.UnitPrice, 'Price should be set in PricebookEntry.');
    }

    @isTest
    static void testCreateProductNegative() {
        Test.startTest();
        try {
            ProductController.createProduct('', -10.00, true, '', 0, 'Each');
            Assert.fail('Should have failed due to invalid name.');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Product name is required.') || e.getMessage().contains('A valid positive price is required.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveProducts() {
        Product2 p = TestDataFactory.createProduct('Active Product', true);
        TestDataFactory.createStandardPricebookEntry(p.Id, 100.00);

        Test.startTest();
        List<PricebookEntry> pbes = ProductController.getActiveProducts();
        Test.stopTest();

        Assert.isTrue(pbes.size() >= 1, 'Should return at least one active product.');
    }

    @isTest
    static void testBulkCreateProducts() {
        ProductService service = new ProductService();
        Test.startTest();
        for(Integer i=0; i<10; i++) {
            service.createProduct('Prod ' + i, 10.00 * (i+1), true, 'Desc', 5.00, 'Each');
        }
        Test.stopTest();

        List<Product2> prods = [SELECT Id FROM Product2 WHERE Name LIKE 'Prod %'];
        Assert.areEqual(10, prods.size(), 'Should create 10 bulk products.');
    }
}
