trigger OpportunityPaymentTrigger on Opportunity (after update) {
    Set<Id> unitIds = new Set<Id>();
    Map<Id, List<Opportunity>> opportunitiesByUnit = new Map<Id, List<Opportunity>>();
    List<Unit__c> unitsToUpdate = new List<Unit__c>();
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    
    // Collect units where payment was made
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        if (opp.Payment_Done__c == true && oldOpp.Payment_Done__c == false && 
            opp.Unit_Number__c != null) {
            unitIds.add(opp.Unit_Number__c);
        }
    }
    
    if (unitIds.isEmpty()) {
        return;
    }
    
    // Query ALL opportunities related to these units, regardless of their stage
    List<Opportunity> allRelatedOpps = [
        SELECT Id, Unit_Number__c, StageName, Payment_Done__c, Blocking_Expiry__c
        FROM Opportunity 
        WHERE Unit_Number__c IN :unitIds
    ];
    
    // Group opportunities by unit
    for (Opportunity opp : allRelatedOpps) {
        if (!opportunitiesByUnit.containsKey(opp.Unit_Number__c)) {
            opportunitiesByUnit.put(opp.Unit_Number__c, new List<Opportunity>());
        }
        opportunitiesByUnit.get(opp.Unit_Number__c).add(opp);
    }
    
    // Query units
    Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
        SELECT Id, Unit_Status__c, Sold_To__c 
        FROM Unit__c 
        WHERE Id IN :unitIds
    ]);
    
    // Process each unit
    for (Id unitId : unitIds) {
        List<Opportunity> unitOpps = opportunitiesByUnit.get(unitId);
        if (unitOpps == null) continue;
        
        // Find the winning opportunity (the one that just made payment)
        Opportunity winningOpp = null;
        for (Opportunity opp : unitOpps) {
            if (opp.Payment_Done__c == true && 
                Trigger.newMap.get(opp.Id).Payment_Done__c != 
                Trigger.oldMap.get(opp.Id).Payment_Done__c) {
                winningOpp = opp;
                break;
            }
        }
        
        if (winningOpp != null) {
            Unit__c unit = unitsMap.get(unitId);
            if (unit != null) {
                // Update unit status and set Blocked_By__c to winning opportunity
                unit.Unit_Status__c = 'Sold';
                unit.Sold_To__c = winningOpp.Id;
                unitsToUpdate.add(unit);
                
                // Update all other opportunities for this unit to Closed Lost
                for (Opportunity opp : unitOpps) {
                    if (opp.Id != winningOpp.Id) {
                        // Close all other opportunities as Lost, regardless of their current stage
                        oppsToUpdate.add(new Opportunity(
                            Id = opp.Id,
                            StageName = 'Closed Lost'
                        ));
                    }
                }
                
                // Update winning opportunity to Closed Won
                oppsToUpdate.add(new Opportunity(
                    Id = winningOpp.Id,
                    StageName = 'Closed Won'
                ));
            }
        }
    }
    
    // Perform DML operations
    if (!oppsToUpdate.isEmpty()) {
        update oppsToUpdate;
    }
    
    if (!unitsToUpdate.isEmpty()) {
        update unitsToUpdate;
    }
}
