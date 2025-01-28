public class UnitTimeoutSchedulable implements Schedulable {
    private List<Id> unitIds;
    
    public UnitTimeoutSchedulable(List<Id> unitIds) {
        this.unitIds = unitIds != null ? unitIds : new List<Id>();
    }
    
    public void execute(SchedulableContext ctx) {
        if (unitIds.isEmpty()) return;
        
        // Query expired opportunities
        List<Opportunity> expiredOpps = [
            SELECT Id, StageName, Payment_Done__c, Unit_Number__c 
            FROM Opportunity 
            WHERE Unit_Number__c IN :unitIds 
            AND StageName = 'Booked'
            AND Blocking_Expiry__c <= :System.now()
            AND Payment_Done__c = false
        ];
        
        if (expiredOpps.isEmpty()) return;
        
        Set<Id> affectedUnitIds = new Set<Id>();
        for (Opportunity opp : expiredOpps) {
            affectedUnitIds.add(opp.Unit_Number__c);
        }
        
        // Bulk query for active bookings
        Map<Id, List<Opportunity>> activeBookingsByUnit = new Map<Id, List<Opportunity>>();
        for (Opportunity opp : [
            SELECT Id, Unit_Number__c 
            FROM Opportunity 
            WHERE Unit_Number__c IN :affectedUnitIds 
            AND StageName = 'Booked'
            AND Blocking_Expiry__c > :System.now()
            AND Payment_Done__c = false
        ]) {
            if (!activeBookingsByUnit.containsKey(opp.Unit_Number__c)) {
                activeBookingsByUnit.put(opp.Unit_Number__c, new List<Opportunity>());
            }
            activeBookingsByUnit.get(opp.Unit_Number__c).add(opp);
        }
        
        // Collect all updates
        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        for (Id unitId : affectedUnitIds) {
            if (!activeBookingsByUnit.containsKey(unitId) || 
                activeBookingsByUnit.get(unitId).isEmpty()) {
                unitsToUpdate.add(new Unit__c(
                    Id = unitId,
                    Unit_Status__c = 'Available'
                ));
            }
        }
        
        // Bulk updates
        if (!expiredOpps.isEmpty()) {
            for (Opportunity opp : expiredOpps) {
                opp.StageName = 'Closed Lost';
            }
            update expiredOpps;
        }
        
        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }
}
