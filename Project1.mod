/*********************************************
 * OPL 22.1.1.0 Model
 * Author: ore20
 * Creation Date: Nov 8, 2025 at 4:18:53 PM
 *********************************************/

//----------------------------------------------------------------------
// Steelco Multi-Period Inventory Model
//----------------------------------------------------------------------

// ----- 1. SETS -----
// Define the sets for products, materials, and time.

setof(string) Products = ...;   // e.g., {"I", "W", "U", "H", "L"}
setof(string) Materials = ...;  // e.g., {"New", "Recycled"}

int numMonths = ...;          // e.g., 12
range Time = 1..numMonths;      // Time periods t = 1 to 12
range Time0 = 0..numMonths;     // Time periods t = 0 to 12 (for inventory)


// ----- 2. PARAMETERS (Data) -----
// These are the fixed values from your problem. They will be
// initialized from the .dat file.

float SP[Products] = ...;                // Selling Price
float DC[Products][Time] = ...;          // Demand
float MC[Materials] = ...;               // Material Cost
float IC = ...;                          // Inventory Cost
float PC[Products] = ...;                // Penalty (Backorder) Cost
float PL[Materials] = ...;               // Purchase Limit
float Yield[Materials] = ...;            // Material Yield
float QR[Products] = ...;                // Quality Requirement (min % of New)


// ----- 3. DECISION VARIABLES -----
// These are the unknown quantities the solver needs to find.
// "float+" means the variable must be >= 0.

dvar float+ buy[Materials][Time];           // Tons of material j purchased in month t
dvar float+ steel[Products][Materials][Time]; // Tons of product i from material j in month t
dvar float+ inv[Products][Time0];           // Tons of product i in inventory at END of month t
dvar float+ back[Products][Time0];          // Tons of product i on backorder at END of month t


// ----- 4. OBJECTIVE FUNCTION -----
// The goal: Maximize total profit.
// Profit = Revenue - Material Cost - Inventory Cost - Backorder Cost

maximize
  // Total Revenue
  sum(t in Time, i in Products, j in Materials) 
    (SP[i] * steel[i,j,t])
    
  // Total Material Cost
  - sum(t in Time, j in Materials) 
    (MC[j] * buy[j,t])
    
  // Total Inventory Cost
  - sum(t in Time, i in Products) 
    (IC * inv[i,t])
    
  // Total Backorder Cost
  - sum(t in Time, i in Products) 
    (PC[i] * back[i,t]);


// ----- 5. CONSTRAINTS -----
// The rules of the problem.

subject to {

  // 1. Material Purchase Limit:
  // Cannot buy more than the monthly limit for each material.
  forall(j in Materials, t in Time)
    ct_PurchaseLimit:
      buy[j,t] <= PL[j];

  // 2. Material Usage:
  // Total production from a material cannot exceed the usable amount purchased.
  forall(j in Materials, t in Time)
    ct_MaterialUsage:
      sum(i in Products) steel[i,j,t] <= Yield[j] * buy[j,t];

  // 3. Quality Requirement:
  // Production from 'New' steel must meet the minimum quality percentage.
  forall(i in Products, t in Time)
    ct_QualityReq:
      steel[i,"New",t] >= QR[i] * (sum(j in Materials) steel[i,j,t]);

  // 4. Inventory Balance:
  // This is the main flow constraint that links all time periods.
  // NetInventory(t) = NetInventory(t-1) + Production(t) - Demand(t)
  forall(i in Products, t in Time)
    ct_InventoryBalance:
      (inv[i,t] - back[i,t]) == (inv[i,t-1] - back[i,t-1]) 
                               + (sum(j in Materials) steel[i,j,t]) 
                               - DC[i,t];

  // 5. Initial and Final Conditions:
  // Must start and end the year with zero inventory and zero backorders.
  
  // Initial (t=0)
  forall(i in Products) {
    ct_InitialInv:  inv[i,0] == 0;
    ct_InitialBack: back[i,0] == 0;
  }
  
  // Final (t=12)
  forall(i in Products) {
    ct_FinalInv:  inv[i,numMonths] == 0;
    ct_FinalBack: back[i,numMonths] == 0;
  }
}

// 6. POST-PROCESSING (Results)
//----------------------------------------------------------------------
execute {
  // --- 1. Display the Main Objective (Total Profit) ---
  writeln("----------------------------------------------------------");
  writeln("          *** STEELCO OPTIMIZATION RESULTS ***");
  writeln("----------------------------------------------------------");
  writeln("Total Profit for 2025: $", cplex.getObjValue());
  writeln();

  // --- 2. Calculate and Display Profit Components ---
  // It's useful to see the individual components of the profit calculation.
  
  var totalRevenue = 0;
  for(var t in Time) {
    for(var i in Products) {
      for(var j in Materials) {
        totalRevenue += SP[i] * steel[i][j][t].solutionValue;
      }
    }
  }
  writeln("  Total Revenue:   $", totalRevenue);

  var totalMaterialCost = 0;
  for(var t in Time) {
    for(var j in Materials) {
      totalMaterialCost += MC[j] * buy[j][t].solutionValue;
    }
  }
  writeln("  Total Material Cost: $", totalMaterialCost);

  var totalInventoryCost = 0;
  for(var t in Time) {
    for(var i in Products) {
      totalInventoryCost += IC * inv[i][t].solutionValue;
    }
  }
  writeln("  Total Inventory Cost:  $", totalInventoryCost);
  
  var totalBackorderCost = 0;
  for(var t in Time) {
    for(var i in Products) {
      totalBackorderCost += PC[i] * back[i][t].solutionValue;
    }
  }
  writeln("  Total Backorder Cost:  $", totalBackorderCost);
  writeln("----------------------------------------------------------");
  writeln();


  // --- 3. Display Detailed Monthly Purchase Plan ---
  // This shows how much of each raw material to buy each month.
  writeln("Monthly Raw Material Purchase Plan (tons):");
  // Write header
  write("Month\t");
  for(var j in Materials) {
    write(j, "\t");
  }
  writeln();
  // Write data rows
  for(var t in Time) {
    write(t, "\t");
    for(var j in Materials) {
      write(buy[j][t].solutionValue, "\t");
    }
    writeln();
  }
  writeln();

  
  // --- 4. Display Detailed Monthly Production Plan ---
  // This shows the total production for each beam type each month.
  writeln("Monthly Beam Production Plan (tons):");
  // Write header
  write("Month\t");
  for(var i in Products) {
    write(i, "\t");
  }
  writeln();
  // Write data rows
  for(var t in Time) {
    write(t, "\t");
    for(var i in Products) {
      var totalSteel = steel[i]["New"][t].solutionValue + steel[i]["Recycled"][t].solutionValue;
      write(totalSteel, "\t");
    }
    writeln();
  }
  writeln();

  
  // --- 5. Display End-of-Month Inventory Levels ---
  // Shows how much inventory (if any) is held at the end of each month.
  writeln("End-of-Month Inventory (tons):");
  // Write header
  write("Month\t");
  for(var i in Products) {
    write(i, "\t");
  }
  writeln();
  // Write data rows
  for(var t in Time) {
    write(t, "\t");
    for(var i in Products) {
      write(inv[i][t].solutionValue, "\t");
    }
    writeln();
  }
  writeln();
  
  
  // --- 6. Display End-of-Month Backorder Levels ---
  // Shows how many backorders (if any) exist at the end of each month.
  writeln("End-of-Month Backorders (tons):");
  // Write header
  write("Month\t");
  for(var i in Products) {
    write(i, "\t");
  }
  writeln();
  // Write data rows
  for(var t in Time) {
    write(t, "\t");
    for(var i in Products) {
      write(back[i][t].solutionValue, "\t");
    }
    writeln();
  }
  writeln("----------------------------------------------------------");

}

