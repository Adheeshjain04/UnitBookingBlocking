public class BookingTimeoutManager {
    public static void scheduleUnitTimeout(Id unitId) {
        // Calculate the time 30 minutes from now
        Datetime scheduleTime = System.now().addMinutes(3);
        
        // Create unique job name based on UnitId
        String jobName = 'UnitTimeout_' + unitId + '_' + System.now().getTime();
        
        // Create Dynamic cron expression for exact time
        String cronExp = '' + scheduleTime.second() + ' ' 
                        + scheduleTime.minute() + ' ' 
                        + scheduleTime.hour() + ' ' 
                        + scheduleTime.day() + ' ' 
                        + scheduleTime.month() + ' ? ' 
                        + scheduleTime.year();
        
        // Schedule the job
        System.schedule(jobName, cronExp, new UnitTimeoutSchedulable(unitId));
    }
}
