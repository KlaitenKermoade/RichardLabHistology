// Semi-Automated Cell Counting - Inside and Outside a User-Declared ROI
	// finished by Klaiten Kermoade 2/19/2025
	// 
	// This script functions as so:
	// 1) Load Image
	// 2) Extract metadata from image name (optional, see below for my specific naming style)
	// 3) Draw ROI (currently guided towards encircling the VP based on substance P staining)
	// 4) Use multipoint tool to select all positive cell bodies
	// 5) Save 1. hand-drawn region ROI and 2. individual multipoint cell selections at a user-defined path
	// 6) save results of cell numbers, overall and inside/outside ROI, to an excel at a user-defined path


//
// Part 0: extracting metadata from image file name
// Note - my file names looked like "KEK4 antVPl sp 20x 5x7" - that is "Rat ID", "approx A/P", "region" (i.e., here ventral pallidum), "hemisphere", "IHC type" (i.e., here substance P), "maginification" and "image tiling"
// Note - many variables are named with the intention of use in the VP
//

	// Get the current image name
	currentName = getTitle();
	
	// Remove the ".tif" part from the file name, replace spaces with underscores, delete underscore that follows abberantly
	baseName = currentName.substring(0, currentName.length - 4);
	baseName = replace(baseName, " ", "_");
	rename(baseName);
		
	// Extract ID (by finding all characters before the first underscore - works at least for KEK 75-108)
	underscorePos = indexOf(baseName, "_");
if (underscorePos != -1) {
    Rat_ID = substring(baseName, 0, underscorePos);
    print("Rat ID: " + Rat_ID);
} else {
    print("No Rat ID found.");
}
	
	// Extract Approximate A/P position based on name (by finding all characters after the first underscore and before "VP" - works at least for KEK 75-108)
	VPPos = indexOf(baseName, "VP");
if (underscorePos != -1 && VPPos != -1 && VPPos > underscorePos) {
 	Approximate_AP = substring(baseName, underscorePos + 1, VPPos);
    print("Approximate A/P position: " + Approximate_AP);
} else {
    print("No approximate A/P position specified.");
}
	
	// Extract hemisphere (should work for pretty much all the images)
	// Check if "VP" is found and then extract the character after it
if (VPPos != -1 && VPPos + 2 < lengthOf(baseName)) {
    letterAfterVP = substring(baseName, VPPos + 2, VPPos + 3);
    print("Letter immediately after 'VP': " + letterAfterVP);
	// Set Hemisphere based on the letter after VP
    if (letterAfterVP == "l") {
        Hemisphere = "Left";
    } else if (letterAfterVP == "r") {
        Hemisphere = "Right";
    } else {
        Hemisphere = "Unknown"; // In case the letter is not "l" or "r"
    }
    print("Hemisphere: " + Hemisphere);
} else {
    print("'VP' not found or no letter after 'VP'.");
}


//
// Part 1: ROI CIRCLING
// Note - since these images were specific for the ventral pallidum, delineated by substance P, user is intended to circle the VP here
// Note - popup boxes are written with the intention of use in the VP
//
	
	
	// Select bounds for the VP	
	setTool("polygon");	
	waitForUser("Select bounds for the VP. Click OK to continue.");	
	roiManager("Add");	
	roiManager("Select", 0);
	roiManager("Rename", "VP boundary");
	roiManager("Show All");
	roiManager("Show None");
	

//
// Part 2: CELL SELECTION & COUNTING
// Note - selects all mCherry positive cells with multi-point tool. 
// Note - FIJI will automatically quantify number of cells that are inside and outside of your ROI
// Note - you will save your hand drawn ROI and location of your multipoint selections 
//	
	
	// Select all cells
	setTool("multipoint");
 	waitForUser("Select all cells. Click OK to continue.");
 	
	
	// Check if any points were selected
	nROIs = roiManager("Count");

if (selectionType() == -1) {
    // If no cells were selected, create a small placeholder ROI
    inside_cells = 0;
	outside_cells = 0;
	total_cells = 0;
    print("No cells selected.");
		
} else {
    roiManager("Add");
    roiManager("Select", 1);
    roiManager("Rename", "Multipoint - all cells");
	
	
	roiManager("Select", 0);  // 0 corresponds to the first ROI
	idx = roiManager("index");  // Get the index of the polygon
	rCount = roiManager("count");
	inside_cells = 0;
	outside_cells = 0;
	total_cells = 0;
	for (i = 0; i < rCount; i++) {
    	if (i != idx) {  // Only check ROIs that are not the polygon
        	roiManager("select", i);
        	getSelectionCoordinates(xpoints, ypoints);
        	roiManager("select", idx);
   				for (j = 0; j < xpoints.length; j++) {
   					total_cells++;  // Increment total points counter
   						if (selectionContains(xpoints[j], ypoints[j])) {
   							print(xpoints[j] + ", " + ypoints[j] + " is inside the polygon");
   							inside_cells++;
   							} else {
   								print(xpoints[j] + ", " + ypoints[j] + " is outside the polygon");
   								outside_cells++;
       						}
      			}
        }
	}
}

	// Create or open the Results Table
	rt = Table.create("Results");
	// Add results in a **single row**
	rowIndex = Table.size;
	Table.set("File Name", rowIndex, baseName);
	Table.set("Rat ID", rowIndex, Rat_ID);
	Table.set("Approximate AP Section", rowIndex, Approximate_AP);
	Table.set("Hemisphere", rowIndex, Hemisphere);
	Table.set("Total Cells", rowIndex, total_cells);
	Table.set("Cells Inside VP", rowIndex, inside_cells);
	Table.set("Cells Outside VP", rowIndex, outside_cells);
	Table.update();

	// Print summary results
	print("Total points overall: " + total_cells);
	print("Total points inside the VP: " + inside_cells);
	print("Total points outside the VP: " + outside_cells);

	// Get user-selected directory for ROIs
	CellNumberPath = "\\EnterROIPathHere\\";
	File.makeDirectory(CellNumberPath);
	
	// Save all ROIs to a .zip file in the new folder
	roiManager("Deselect");
	roiManager("Save", CellNumberPath + "/" + baseName + " - ROIs.zip");	
	
	// Write and save results to an excel file.
	Overall_Results = "Results";
	run("Read and Write Excel", "no_count_column file=\\EnterROIPathHere\\Results.xlsx stack_results sheet=" + Overall_Results + " dataset_label=" + baseName); 
	
	// clear everything so it doesn't mess up your next run through
	roiManager("Deselect");
	roiManager("Reset");			 // Clear the ROI Manager 
	run("Close All");                // Close all open images
	run("Clear Results");            // Close the Results panel
	
	print("Finished! ROIs saved, Results saved.");
	