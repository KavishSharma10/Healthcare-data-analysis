// Changed Date of Visit to date
#"Changed Type with Locale" = Table.TransformColumnTypes(#"Changed column type", {{"Date of Visit", type date}}, "en-US"),

// Changed Follow-Up Visit Date to date
#"Changed Type with Locale1" = Table.TransformColumnTypes(#"Changed Type with Locale", {{"Follow-Up Visit Date", type date}}, "en-US"),

// Changed Discharge Date and Admitted Date to date
#"Changed Type with Locale2" = Table.TransformColumnTypes(#"Changed Type with Locale1", {{"Discharge Date", type date}, {"Admitted Date", type date}}, "en-US"),

// Renamed Room Charges column
#"Renamed Columns" = Table.RenameColumns(#"Changed Type with Locale2", {{"Room Charges(daily rate)", "Room Daily Rate"}}),

// Replaced N/A with Not Admitted
#"Replaced Value" = Table.ReplaceValue(#"Renamed Columns", "N/A", "Not Admitted", Replacer.ReplaceText, {"Room Type"})
