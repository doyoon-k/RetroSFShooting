namespace RetroSF
{
    public static class EndingResolver
    {
        public static string Resolve(RunState run)
        {
            var living = run.Survivors();
            if (living.Count == 0) return "extinction";
            if (!run.bossCleared) return "";
            switch (living.Count)
            {
                case 1: return "last_signal";
                case 2:
                    foreach (var pilot in living)
                        if (pilot.isAi) return "betrayal";
                    return "unknown_horizon";
                case 3:
                case 4: return "unknown_horizon";
                case 5: return "cost_of_dawn";
                default: return "new_home";
            }
        }
    }
}
