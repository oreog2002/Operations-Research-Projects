/*****************************************************************************
 * OPL Model for ToyCo Workforce Decision
 * Project 2 - Modeling and Solving Integer Programs
 *****************************************************************************/

// --- 1. SETS AND INDICES ---
int NbWeeks = 52;
range Weeks = 1..NbWeeks;

{string} Factories = ...; // Set of factory names (e.g., "Oregon", "New Jersey")

// --- 2. PARAMETERS ---
// Demand Forecast
int Demand[Weeks] = ...;

// Factory Data
int Capacity[Factories] = ...;       // Max labor hours per week
int FixedCost[Factories] = ...;      // Yearly fixed cost to keep open
int InitialEmployees[Factories] = ...; // Employees available at start of Week 1

// Costs & Productivity Constants
float WageReg = 560;    // $14/hr * 40 hrs
float WageNew = 400;    // $10/hr * 40 hrs
float SevPay = 560;     // 1 week salary ($14 * 40)
float CostOT = 21;      // $14 * 1.5
int ProdLine = 40;      // Useful hours from Line worker
int ProdTrain = 20;     // Useful hours from Trainer
int ProdNew = 0;        // Useful hours from New Hire (Training)
int MaxOT = 10;         // Max OT hours per employee

// --- 3. DECISION VARIABLES ---
dvar boolean Open[Factories];              // 1 if factory is kept open, 0 otherwise
dvar int+ W[Factories][Weeks];             // Regular workforce available at start of week
dvar int+ H[Factories][Weeks];             // New Hires at start of week
dvar int+ F[Factories][Weeks];             // Fired employees at start of week
dvar int+ L[Factories][Weeks];             // Line (Full-time) workers
dvar int+ Tr[Factories][Weeks];            // Trainers
dvar float+ O[Factories][Weeks];           // Overtime hours (Continuous)

// --- 4. OBJECTIVE FUNCTION ---
// Minimize Total Cost: Fixed Costs + Wages + Severance + Overtime
dexpr float TotalFixedCost = sum(f in Factories) (FixedCost[f] * Open[f]);
dexpr float TotalWages = sum(f in Factories, t in Weeks) 
    (WageReg * W[f][t] + WageNew * H[f][t] + SevPay * F[f][t] + CostOT * O[f][t]);

minimize TotalFixedCost + TotalWages;

// --- 5. CONSTRAINTS ---
subject to {
  
  // A. Logic Constraints
  // 1. If NJ (Factory 2) is open, OR (Factory 1) must be open.
  // Note: Ensure your Excel names match these strings exactly.
  Open["New Jersey"] <= Open["Oregon"];
  
  // 2. Either NJ or NY must be open (or both).
  Open["New Jersey"] + Open["New York"] >= 1;

  forall(f in Factories, t in Weeks) {
    
    // B. Workforce Balance (Flow Conservation)
    if (t == 1) {
      // Week 1: Initial employees - Fired + 0 (No hires ready from week 0)
      W[f][t] == InitialEmployees[f] - F[f][t];
    } else {
      // Week t: Previous Regulars - Fired + Trained Hires from t-1
      W[f][t] == W[f][t-1] - F[f][t] + H[f][t-1];
    }
    
    // C. Assignment Constraint
    // Regulars are split into Line workers and Trainers (can have idle workers)
    L[f][t] + Tr[f][t] <= W[f][t];
    
    // D. Training Constraint
    // Every New Hire needs 1 Trainer
    H[f][t] <= Tr[f][t];
    
    // E. Overtime Constraint
    // Max 10 hours per Regular employee (Line + Trainer)
    O[f][t] <= MaxOT * (L[f][t] + Tr[f][t]);
    
    // F. Factory Capacity Constraint
    // Total physical hours (Line + Trainer + NewHire + Overtime) <= Capacity
    // NOTE: New Hires work 40 hours even if they produce 0 useful output
    40 * L[f][t] + 40 * Tr[f][t] + 40 * H[f][t] + O[f][t] <= Capacity[f] * Open[f];
  }
  
  // G. Demand Constraint (Global)
  // Total USEFUL hours must meet demand
  forall(t in Weeks) {
    sum(f in Factories) (ProdLine * L[f][t] + ProdTrain * Tr[f][t] + O[f][t]) >= Demand[t];
  }
}

// --- 6. POST-PROCESSING ---
execute {
  writeln("Optimization Complete.");
  writeln("Total Cost: $", cplex.getObjValue());
  
  writeln("------------------------------------------------");
  writeln("Factory Status (Closed Factories Omitted):");
  for(var f in Factories) {
     if (Open[f] == 1) {
       writeln(f, " is OPEN.");
     }
  }
  
  writeln("------------------------------------------------");
  writeln("Detailed Schedule for New Jersey (Example):");
  writeln("Week | Regulars | Hired | Fired | Trainers | Line | Overtime");
  for(var t in Weeks) {
    if (Open["New Jersey"] == 1) {
       writeln(t, "    | ", W["New Jersey"][t], "      | ", H["New Jersey"][t], 
               "     | ", F["New Jersey"][t], "     | ", Tr["New Jersey"][t], 
               "        | ", L["New Jersey"][t], "    | ", O["New Jersey"][t]);
    }
  }
}