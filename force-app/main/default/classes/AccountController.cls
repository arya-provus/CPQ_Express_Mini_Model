public with sharing class AccountController {

    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts(String searchTerm, String typeFilter, String industryFilter) {
        String query = 'SELECT Id, Name, AccountNumber, Type, Industry, Website, Phone FROM Account';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(searchTerm)) {
            String keyword = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            conditions.add('(Name LIKE \'' + keyword + '\' OR Phone LIKE \'' + keyword + '\')');
        }
        if (String.isNotBlank(typeFilter) && typeFilter != 'All Types') {
            conditions.add('Type = \'' + String.escapeSingleQuotes(typeFilter) + '\'');
        }
        if (String.isNotBlank(industryFilter) && industryFilter != 'All Industries') {
            conditions.add('Industry = \'' + String.escapeSingleQuotes(industryFilter) + '\'');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' ORDER BY Name LIMIT 200';
        return Database.query(query);
    }

    @AuraEnabled
    public static void deleteAccount(Id accountId) {
        Account acc = new Account(Id = accountId);
        delete acc;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAccountTypes() {
        List<String> types = new List<String>();
        Schema.DescribeFieldResult fieldResult = Account.Type.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            types.add(entry.getValue());
        }
        return types;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAccountIndustries() {
        List<String> industries = new List<String>();
        Schema.DescribeFieldResult fieldResult = Account.Industry.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            industries.add(entry.getValue());
        }
        return industries;
    }
}
