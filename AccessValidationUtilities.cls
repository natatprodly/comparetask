public with sharing class AccessValidationUtilities {
    public class AccessValidationException extends Exception {}

    public static String getInQueryPart(List<Id> values) {
        String query = 'IN (';
        for( Id value : values ) {
            query += '\'' + String.escapeSingleQuotes( (String)value ) + '\',';
        }

        query = query.substring(0, query.length() - 1);
        query += ')';

        return query;
    }

    public static void deleteAsUser(List<SObject> sobjects) {

    	//MD-2942
    	if(sobjects == null || sobjects.size() == 0)
    		return;

        Schema.DescribeSObjectResult objectDescribe = sobjects.getSObjectType().getDescribe();
        if( objectDescribe.isDeletable() == false ) {
            throw new AccessValidationException('Permission denied. Unable to delete record in object: ' + objectDescribe.getName());
        }

        delete sobjects;
    }

    public static SObject[] upsertRelationshipsAsUser(List<Relationship__c> relationships) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Relationship__c, Schema.sObjectType.Relationship__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(relationships, fieldResults);
    }

    public static SObject[] upsertDataSetFieldsAsUser(List<Data_Set_Field__c> dataSetFields) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Data_Set_Field__c, Schema.sObjectType.Data_Set_Field__c.getName() ); //MD-1345
        return AccessValidationUtilities.upsertAsUser(dataSetFields, fieldResults);
    }

    public static SObject[] upsertDataSetsAsUser(List<DataSet__c> dataSets) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.DataSet__c, Schema.sObjectType.DataSet__c.getName() ); //MD-1345
        return AccessValidationUtilities.upsertAsUser(dataSets, fieldResults);
    }

    //MD-924
    public static SObject[] upsertDeploymentResultAsUser(List<Deployment_Result__c> deploymentResult) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Result__c, Schema.sObjectType.Deployment_Result__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(deploymentResult, fieldResults);
    }

    public static SObject[] upsertDeploymentsAsUser(List<Deployment__c> deployments) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment__c, Schema.sObjectType.Deployment__c.getName());
        return AccessValidationUtilities.upsertAsUser(deployments, fieldResults);
    }

    public static SObject[] upsertQueryFiltersAsUser(List<Query_Filter__c> queryFilters) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Query_Filter__c, Schema.sObjectType.Query_Filter__c.getName());
        return AccessValidationUtilities.upsertAsUser(queryFilters, fieldResults);
    }

    //MD-924
    public static SObject[] upsertConnectionAsUser(List<Connection__c> conn) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Connection__c, Schema.sObjectType.Connection__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(conn, fieldResults);
    }
    public static SObject[] upsertAsUser(List<SObject> sobjects, Map<String,Schema.DescribeFieldResult> fieldResults) {
        Schema.DescribeSObjectResult objectDescribe = sobjects.getSObjectType().getDescribe();

        if( !objectDescribe.isUpdateable() || !objectDescribe.isCreateable() ) {
            throw new AccessValidationException('Permission denied. Unable to upsert record in object: ' + objectDescribe.getName());
        }
         //MD-610
        Set<Id> sObjectIds = new Set<Id>();
        for(SObject sObj : sObjects) {

            if(sObj.Id != null) {
                sObjectIds.add(sObj.Id);
            }
        }

        String sObjectsQuery = 'SELECT ';

        for( Schema.DescribeFieldResult fieldResult : fieldResults.values() ) {
            sObjectsQuery += fieldResult.getName() + ',';
        }
        sObjectsQuery = sObjectsQuery.removeEnd(',');
        sObjectsQuery += ' from ' + objectDescribe.getName() + ' where Id IN: sobjectIds';
        List<sobject> queryObjectValues =  Database.query(sObjectsQuery);

        Map<Id,SObject> mapSObjectsRecordsWithIds = new Map<Id,SObject>();
        if(queryObjectValues.size() > 0){
            for(SObject sObj:queryObjectValues) {
                mapSObjectsRecordsWithIds.put(sObj.Id,sObj);
            }
        }

        //MD-1017: Added a check to bypass the custom formula field as formula fields derive their value at runtime and can't be updated
        for(SObject obj : sobjects) {
            for( Schema.DescribeFieldResult fieldResult : fieldResults.values() ) {

                if( fieldResult.isCustom() && (!fieldResult.isCalculated()) && (!fieldResult.isAutoNumber())
                     && ((!fieldResult.isUpdateable() || !fieldResult.isCreateable())
                        && ((mapSobjectsRecordsWithIds.containsKey(obj.Id) && ((mapSobjectsRecordsWithIds.get(obj.Id)).get(fieldResult.getName())) != obj.get(fieldResult.getName()) )
                          && (!mapSobjectsRecordsWithIds.containsKey(obj.Id) && (obj.get(fieldResult.getName()) != null && obj.get(fieldResult.getName()) != '' ))))
                    && ( !( objectDescribe.getName() == ProdlyConstants.PACKAGE_NAMESPACE + 'Relationship__c' && fieldResult.getName() == ProdlyConstants.PACKAGE_NAMESPACE + 'ParentDataSet__c' ) )//MD-3734
                    && ( !( objectDescribe.getName() == ProdlyConstants.PACKAGE_NAMESPACE + 'Data_Set_Field__c' && fieldResult.getName() == ProdlyConstants.PACKAGE_NAMESPACE + 'Data_Set__c' ) ) ) {//MD-3734
                        throw new AccessValidationException('Permission denied. Unable to upsert record in object: ' + objectDescribe.getName() + ' and field: ' + fieldResult.getName());
                }
            }
        }

        //MD-3632
        try{
        	upsert sobjects;

        } catch (Exception e){
        	if( e != null && e.getMessage() != null && e.getMessage().contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST') && e.getMessage().contains('Simulation') ) {
            	throw new ProdlyCustomException(Label.MISSING_SIMULATION_DEPLOYMENT_RESULT_TYPE_ERROR);
           	} else {
        		throw new ProdlyCustomException(Label.ERROR_UNKNOWN_ERROR_WHILE_COMMITTING_TO_DATABASE);
           	}
        }
        return sobjects;
    }

    public static List<Data_Set_Field__c> queryDataSetFieldsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Data_Set_Field__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345
        return (List<Data_Set_Field__c>)AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers, additionalQuery);
    }

    public static DataSet__c queryDataSetAsUser(String queryQualifiers, String additionalQuery) {
      //MD-1888 Start
      List<DataSet__c> dataSets = (List<DataSet__c>)queryDataSetsAsUser(queryQualifiers, additionalQuery);
      if(dataSets == null)
        return null;
        //MD-1888 End
        return dataSets[0];
    }

    public static DataSet__c queryDataSetAsUser(String queryQualifiers) {
        //MD-1888 Start
        List<DataSet__c> dataSets = (List<DataSet__c>)queryDataSetsAsUser(queryQualifiers);
        if(dataSets == null)
          return null;
          //MD-1888 End
          return dataSets[0];
      }

    public static List<DataSet__c> queryDataSetsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.DataSet__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345

        SObject[] objectResults = AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers, additionalQuery);
        if( objectResults == null || objectResults.size() == 0 ) {
            return null;
        }
        return objectResults;
    }

    public static List<DataSet__c> queryDataSetsAsUser(String queryQualifiers) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.DataSet__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers);
    }

    public static List<Connection__c> queryConnectionsAsUser(String queryQualifiers) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Connection__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers);
    }

    //MD-610
    public static List<Folder__c> queryFolderAsUser(String queryQualifiers) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Folder__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers);
    }

    public static List<Query_Filter__c> queryQueryFiltersAsUser(String queryQualifiers) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Query_Filter__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers);
    }

    public static List<Deployment__c> queryDeploymentsAsUser(String queryQualifiers) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers);
    }

    public static List<Deployment_Result__c> queryDeploymentResultAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Result__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName()); //MD-1345
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }

    public static List<Metadata_Deployment_Result__c> queryMetadataDeploymentResultsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Metadata_Deployment_Result__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }

    //MD-1053 - Validate sobject query, MD-924
    public static void validateSObjectAsUser(String objectType){

        SObjectType objToken = Schema.getGlobalDescribe().get(objectType);
        DescribeSObjectResult objectDescribe = objToken.getDescribe();
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());
        validateObjectFieldsAccessible(objectDescribe, fieldResults);
    }

    //MD-1401 - Getting "Apex CPU time limit exceeded" error when import the CPQ data set.
    public static void validateSObjectTypeQueryAsUser(String objectType){

        SObjectType objToken = Schema.getGlobalDescribe().get(objectType);
        if(objToken == null)
            return;
        DescribeSObjectResult objectDescribe = objToken.getDescribe();
        if( !objectDescribe.isAccessible() || (!objectDescribe.isCreateable() && !objectDescribe.isUpdateable()) ||
            objectDescribe.isDeprecatedAndHidden() || !objectDescribe.isQueryable()) {
            throw new AccessValidationException('Permission denied. Unable to query record in object: ' + objectDescribe.getName());
        }
    }

    //MD-1053 - Whether object can deleted
    public static void validateSObjectDeleteAccess(String objectType){

        SObjectType objToken = Schema.getGlobalDescribe().get(objectType);
        DescribeSObjectResult objectDescribe = objToken.getDescribe();
        if( !objectDescribe.isDeletable() ) {
            throw new AccessValidationException('Permission denied. Unable to delete the record for: ' + objectDescribe.getName());
        }
    }

    public static SObject[] queryAsUser(Schema.DescribeSObjectResult objectDescribe, Map<String,Schema.DescribeFieldResult> fieldResults, String queryQualifiers) {
        return queryAsUser(objectDescribe, fieldResults, queryQualifiers, null);
    }

    public static SObject[] queryAsUser(Schema.DescribeSObjectResult objectDescribe, Map<String,Schema.DescribeFieldResult> fieldResults, String queryQualifiers, String additionalQuery) {
        validateObjectFieldsAccessible(objectDescribe, fieldResults);

        String sobjectsQuery = 'SELECT ';

        for( Schema.DescribeFieldResult fieldResult : fieldResults.values() ) {
            //MD-3726
            if(ProdlyConstants.QUERY_UNAVAILABEL_FIELDS.contains(fieldResult.getName())||(objectDescribe.getName() != ProdlyConstants.PACKAGE_NAMESPACE+ProdlyConstants.OBJECT_API_NAME_DEPLOYMENT_RESULT && ProdlyConstants.SYSTEM_FIELDS_TO_EXCLUDE.contains(fieldResult.getName()))
            ||(objectDescribe.getName() == ProdlyConstants.PACKAGE_NAMESPACE+ProdlyConstants.OBJECT_API_NAME_CONNECTION && ProdlyConstants.CONNECTION_FIELDS_TO_EXCLUDE.contains(fieldResult.getName())))//MD-3799
                continue;
            sobjectsQuery += fieldResult.getName() + ',';
        }

        if( additionalQuery != null ) {
            sobjectsQuery += ( ' ' + additionalQuery );
        } else {
            sobjectsQuery = sobjectsQuery.substring(0, sobjectsQuery.length() - 1);
        }

        sobjectsQuery += ' from ' + objectDescribe.getName() + ' ' + ( queryQualifiers == null ? '' : queryQualifiers );

        System.debug('sobjectsQuery****************'+sobjectsQuery);
        return Database.query(sobjectsQuery);

    }

    public static void validateObjectFieldsAccessible(Schema.DescribeSObjectResult objectDescribe) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345
        validateObjectFieldsAccessible(objectDescribe, fieldResults);
    }

    public static void validateObjectFieldsAccessible(Schema.DescribeSObjectResult objectDescribe, Map<String,Schema.DescribeFieldResult> fieldResults) {
        if( !objectDescribe.isAccessible() ) {
            throw new AccessValidationException('Permission denied. Unable to query record in object: ' + objectDescribe.getName());
        }

        for( Schema.DescribeFieldResult fieldResult : fieldResults.values() ) {
            if( !fieldResult.isAccessible() ) {
                throw new AccessValidationException('Permission denied. Unable to query record in object: ' + objectDescribe.getName() + ' and field: ' + fieldResult.getName());
            }
        }
    }

    //=======================================Sub query==========================================
    //MD-1053
    public static String getDataSetRelationshipsSubquery() {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.DataSet__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName()); //MD-1345

        //MD-1389 , MD-1388 , Md-1885 , MD-3361
        String query = '(SELECT Id, Name, ChildDataSet__c, ParentDataSet__c, Enforce_Strict_Query_Filter__c,Child_Selected__c,Parent_Selected__c, Stub_Enable__c,Deployment_Order_Child__c,Deployment_Order_Parent__c from ChildRelationships__r where ChildDataSet__r.Active__c = true' + ')';
        query += ( ', (SELECT Id, Name, ParentDataSet__c, ChildDataSet__c, Enforce_Strict_Query_Filter__c,Child_Selected__c,Parent_Selected__c, Stub_Enable__c,Deployment_Order_Child__c,Deployment_Order_Parent__c from ParentRelationships__r where ParentDataSet__r.Active__c = true' + ')' );

        return query;
    }

    public static String getDataSetFieldsSubqueryEditor() {
       Schema.DescribeSObjectResult dataSetFieldObjectDescribe = Schema.sObjectType.Data_Set_Field__c;
        Map<String,Schema.DescribeFieldResult> dataSetFieldFieldResults = DeploymentUtils.getFieldDescribes(dataSetFieldObjectDescribe, dataSetFieldObjectDescribe.getName()); //MD-1345

        String sobjectsQuery = '(SELECT ';

        for( Schema.DescribeFieldResult fieldResult : dataSetFieldFieldResults.values() ) {
            sobjectsQuery += fieldResult.getName() + ',';
        }

        sobjectsQuery = sobjectsQuery.substring(0, sobjectsQuery.length() - 1);

        sobjectsQuery += ' from Data_Set_Fields__r)';

        return sobjectsQuery;
    }

    public static String getDataSetRelationshipsSubqueryEditor() {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.DataSet__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());   //MD-1345

        String childDataSetFieldsQuery = '', parentDataSetFieldsQuery = '';

        childDataSetFieldsQuery += ( 'ChildDataSet__r.Id, ChildDataSet__r.ObjectName__c' );
        parentDataSetFieldsQuery += ( 'ParentDataSet__r.Id, ParentDataSet__r.ObjectName__c' );

        Schema.DescribeSObjectResult dataSetFieldObjectDescribe = Schema.sObjectType.Data_Set_Field__c;
        Map<String,Schema.DescribeFieldResult> dataSetFieldFieldResults = DeploymentUtils.getFieldDescribes(dataSetFieldObjectDescribe, dataSetFieldObjectDescribe.getName()); //MD-1345

        //MD-1389 , MD-1388 , MD-1885, MD-3361
        String query = '(SELECT Name, ChildDataSet__c,Deployment_Order_Child__c,Deployment_Order_Parent__c, ParentDataSet__c, Enforce_Strict_Query_Filter__c,Child_Selected__c,Parent_Selected__c, Stub_Enable__c, ' + childDataSetFieldsQuery + ', ' + parentDataSetFieldsQuery + ' from ChildRelationships__r' + ')';
        query += ( ', (SELECT Name, ParentDataSet__c, ChildDataSet__c, Deployment_Order_Child__c,Deployment_Order_Parent__c,Enforce_Strict_Query_Filter__c,Child_Selected__c,Parent_Selected__c, Stub_Enable__c, ' + parentDataSetFieldsQuery + ', ' + childDataSetFieldsQuery + ' from ParentRelationships__r' + ')' );

        return query;
    }

    //MD-1702
    public static String getSubquery(String objectApiName){

    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
    Schema.DescribeSObjectResult objectDescribeResult = objectType.getDescribe();
    Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribeResult, objectDescribeResult.getName());

    String sobjectsQuery = 'SELECT ';

        for( Schema.DescribeFieldResult fieldResult : fieldResults.values() ) {
            sobjectsQuery += fieldResult.getName() + ',';
        }

        sobjectsQuery = sobjectsQuery.substring(0, sobjectsQuery.length() - 1);
        return sobjectsQuery;
    }
    //=======================================Sub query end==========================================

    //MD-610
    public static List<Folder__c> getSelectedFolderList(String searchString) {
        List<Folder__c> folders = new List<Folder__c>();

        if(searchString != '')
            folders = AccessValidationUtilities.queryFolderAsUser('where Name LIKE \'' + searchString + '%\' ');
        else
            folders = AccessValidationUtilities.queryFolderAsUser(' Limit 20');
        return folders;
    }

   //MD-924
    public static List<Data_Set_Template__c> queryDataSetTemplatesAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Data_Set_Template__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-924
    public static SObject[] upsertDataSetTemplatesAsUser(List<Data_Set_Template__c> dataSetTemplates) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Data_Set_Template__c, Schema.sObjectType.Data_Set_Template__c.getName());
        return AccessValidationUtilities.upsertAsUser(dataSetTemplates, fieldResults);
    }
    //MD-924
    public static List<Data_Set_Template_Entry__c> queryDataSetTemplateEntriesAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Data_Set_Template_Entry__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-924
    public static SObject[] upsertDataSetTemplateEntriesAsUser(List<Data_Set_Template_Entry__c> dataSetTemplateEntries) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Data_Set_Template_Entry__c, Schema.sObjectType.Data_Set_Template_Entry__c.getName());
        return AccessValidationUtilities.upsertAsUser(dataSetTemplateEntries, fieldResults);
    }

    //MD-924
    public static List<ContentVersion> queryContentVersionAsUser(String queryQualifiers, String additionalQuery){
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.ContentVersion;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers, additionalQuery);
    }
    //MD-924
    public static List<Deployment_Data_Set_Result__c> queryDeploymentDataSetResultAsUser(String queryQualifiers, String additionalQuery){
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Data_Set_Result__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers, additionalQuery);
    }
    //MD-924
    public static SObject[] upsertDeploymentDataSetResultAsUser(List<Deployment_Data_Set_Result__c> deploymentDataSetResult) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Data_Set_Result__c, Schema.sObjectType.Deployment_Data_Set_Result__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(deploymentDataSetResult, fieldResults);
    }
    //MD-924
    public static List<Deployment_Plan_Result__c> queryDeploymentPlanResultAsUser(String queryQualifiers, String additionalQuery){
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Plan_Result__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe, objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers, additionalQuery);
    }
    //MD-924
    public static SObject[] upsertDeploymentPlanResultAsUser(List<Deployment_Plan_Result__c> deploymentPlanResult) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Plan_Result__c, Schema.sObjectType.Deployment_Plan_Result__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(deploymentPlanResult, fieldResults);
    }
    //MD-924
    public static SObject[] upsertDeploymentPlanStepResultAsUser(List<Deployment_Plan_Step_Result__c> deploymentPlanStepResult) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Plan_Step_Result__c, Schema.sObjectType.Deployment_Plan_Step_Result__c.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(deploymentPlanStepResult, fieldResults);
    }
    //MD-924
    public static SObject[] upsertContentVersionAsUser(List<ContentVersion> contentVersion) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.ContentVersion, Schema.sObjectType.ContentVersion.getName()); //MD-1345
        return AccessValidationUtilities.upsertAsUser(contentVersion, fieldResults);
    }
    //MD-924
    public static List<Relationship__c> queryRelationshipsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Relationship__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1702
    public static List<Deployment_Plan__c> queryDeploymentPlansAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Plan__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1702
    public static SObject[] upsertDeploymentPlansAsUser(List<Deployment_Plan__c> deploymentPlans) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Plan__c, Schema.sObjectType.Deployment_Plan__c.getName());
        return AccessValidationUtilities.upsertAsUser(deploymentPlans, fieldResults);
    }
    //MD-1702
    public static List<Deployment_Plan_Step__c> queryDeploymentPlanStepsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Plan_Step__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1702
    public static SObject[] upsertDeploymentPlanStepsAsUser(List<Deployment_Plan_Step__c> deploymentPlans) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Plan_Step__c, Schema.sObjectType.Deployment_Plan_Step__c.getName());
        return AccessValidationUtilities.upsertAsUser(deploymentPlans, fieldResults);
    }
    //MD-1702
    public static SObject[] upsertDeploymentPlanItemsAsUser(List<Deployment_Plan_Item__c> deploymentPlans) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Deployment_Plan_Item__c, Schema.sObjectType.Deployment_Plan_Item__c.getName());
        return AccessValidationUtilities.upsertAsUser(deploymentPlans, fieldResults);
    }
    //MD-2942
    public static SObject[] upsertFieldValueMappingsAsUser(List<Field_Value_Mapping__c> fieldValueMapping) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Field_Value_Mapping__c, Schema.sObjectType.Field_Value_Mapping__c.getName());
        return AccessValidationUtilities.upsertAsUser(fieldValueMapping, fieldResults);
    }
	//MD-3033
    public static List<Field_Value_Mapping__c> queryFieldValueMappingsAsUser(String queryQualifiers, String additionalQuery) {
    	Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Field_Value_Mapping__c;
    	Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
    	return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
	//MD-2713
    public static SObject[] upsertEventControlsAsUser(List<Event_Control__c> eventControls) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Event_Control__c, Schema.sObjectType.Event_Control__c.getName());
        return AccessValidationUtilities.upsertAsUser(eventControls, fieldResults);
    }
    //MD-2713
    public static List<Event_Control__c> queryEventControlsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Event_Control__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-2713
    public static SObject[] upsertEventControlItemsAsUser(List<Event_Control_Item__c> eventControlItems) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Event_Control_Item__c, Schema.sObjectType.Event_Control_Item__c.getName());
        return AccessValidationUtilities.upsertAsUser(eventControlItems, fieldResults);
    }
    //MD-2713
    public static List<Event_Control_Item__c> queryEventControlItemsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Event_Control_Item__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-2900
    public static SObject[] upsertTransformationsAsUser(List<Transformation__c> transformations) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Transformation__c, Schema.sObjectType.Transformation__c.getName());
        return AccessValidationUtilities.upsertAsUser(transformations, fieldResults);
    }
    //MD-2900
    public static List<Transformation__c> queryTransformationsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Transformation__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-2900
    public static List<RecordType> queryRecordTypesAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.RecordType;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-3125
    public static List<Deployment_Record_Result__c> queryDeploymentRecordResultsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Record_Result__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-2783
    public static List<Deployment_Activity_Entry__c> queryDeploymentActivityEntriesAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Deployment_Activity_Entry__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1375
    public static List<Invocation_Template__c> queryInvocationTemplatesAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Invocation_Template__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1375
    public static SObject[] upsertInvocationTemplatesAsUser(List<Invocation_Template__c> invocationTemplates) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Invocation_Template__c, Schema.sObjectType.Invocation_Template__c.getName());
        return AccessValidationUtilities.upsertAsUser(invocationTemplates, fieldResults);
    }
    //MD-1375
    public static List<Invocation__c> queryInvocationsAsUser(String queryQualifiers, String additionalQuery) {
        Schema.DescribeSObjectResult objectDescribe = Schema.sObjectType.Invocation__c;
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes(objectDescribe,objectDescribe.getName());
        return AccessValidationUtilities.queryAsUser(objectDescribe, fieldResults, queryQualifiers,additionalQuery);
    }
    //MD-1375
    public static SObject[] upsertInvocationsAsUser(List<Invocation__c> invocations) {
        Map<String,Schema.DescribeFieldResult> fieldResults = DeploymentUtils.getFieldDescribes( Schema.sObjectType.Invocation__c, Schema.sObjectType.Invocation__c.getName());
        return AccessValidationUtilities.upsertAsUser(invocations, fieldResults);
    }
}