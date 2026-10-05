// Added a custom column for Age Group
#"Added Custom" = Table.AddColumn(#"Changed column type", "Age Group", each
    if [Age] < 30 then "18–29"
    else if [Age] >= 30 and [Age] <= 44 then "30–44"
    else if [Age] >= 45 and [Age] <= 59 then "45–59"
    else "60+"),

// Merged with cities table
#"Merged Queries" = Table.NestedJoin(#"Added Custom", {"City ID"}, cities, {"City ID"}, "cities", JoinKind.LeftOuter),

// Expanded City column
#"Expanded cities" = Table.ExpandTableColumn(#"Merged Queries", "cities", {"City"}, {"City"})
