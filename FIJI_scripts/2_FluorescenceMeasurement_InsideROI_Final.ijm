// High-throughput LHb fluorescence measurement with FIJI
	// Started by Emaleigh Hulet 4/17/2025, finished by Klaiten Kermoade 5/20/2025
	
	// The intention of this program is to collect fluorescence data (mean & integrated density) within user-selected regions.
	// It follows a few basic steps:
	// 1. Split image channels 
	// 2. Adjust DAPI channel luminance settings to user preference
	// 3. Select ROIs based on DAPI channel (for this code, we will be selected the left/right lateral habenula)
	// 4. Select control regions based on DAPI channel using the same boundary shapes as previously-selected ROIs (for this code, selecting an arbitrary user-defined area within the thalamus)
	// 5. Collect fluorescence data using FIJI automation (including area, mean, integrated density, and raw integrated density). It will also collect the Rat ID number (i.e., KEK 4) and slice number (i.e. LHb 1), based on the image title.
	// 6. Store fluorescence data in a stacked excel sheet & store ROIs (in a user-defined sheet & folder)
	
	// The user must open and select an image in FIJI for the program to run effectively
	// Of note, since the Results table is occupied by measurements and is needed to run Read2Excel, we must construct a table called TempResults and overwrite it to the Results table just before saving. A bit clunky, but necessary
	// Also, be mindful of the user-defined path for the output - you might need to change these. Make sure things are saving the way you want before you run through a bunch of images!!
	
	// Clear all important panels before starting
	roiManager("Deselect");	
	roiManager("Reset");			 // Clear the ROI Manager 
	run("Clear Results");            // Close the Results panel
	
	//
	// Part 0: extracting metadata from image file name
	// Note - my file names looked like "KEK4 LHb1 10x 5x3 hr 250430" - that is "Rat ID", "region" (i.e., here lateral habenula), "slice number", "maginification", "image tiling", "image type" (i.e., high resolution), "date"
	// Note - many variables are named with the intention of use in the LHb
	//
	
	// Get the current image name
	baseName = getTitle();
	
	// Remove the ".tif" part from the file name
	currentName = baseName.substring(0, baseName.length - 4);
	rename(currentName);
	
	// Extract Rat ID (assuming it's the first part of the file name)
	splitName = split(currentName, " ");
	Rat_ID = splitName[0]; // Assuming the Rat ID is the first part of the name
	Slice_Number = splitName[1]; // Assuming the Slice Number is the second part of the name
	
	
//
// Part 1: ROI CIRCLING
// Note - these images were specific for the lateral habenula, which we would circle around DAPI signal. We'd then move around the same ROI selection to be placed around the dorsal thalamic region of the same hemisphere for each. 
// Note - popup boxes written accordingly (LHb, thalamus)
//	

	
	run("Split Channels");

	// Construct channel window names dynamically
	redWindow = currentName + " (red)";
	greenWindow = currentName + " (green)";
	blueWindow = currentName + " (blue)";

	// Get rid of green channel & choose the DAPI channel, from which regions will be constructed
	close(greenWindow);
	selectWindow(blueWindow);
	run("Blue");

	// First, auto adjust B/C, then prompt user to shift the luminance settings to aid in region selection
	run("Enhance Contrast", "saturated=0.35");
	run("Brightness/Contrast...");
	waitForUser("Alter Brightness/Contrast to aid in selection, as you see fit. Click OK to continue.");
	run("Close");


	// Select bounds for the Left LHb 
	setTool("polygon");
	waitForUser("Select bounds for the Left LHb. Click OK to continue.");
	roiManager("Add");
	roiManager("Select", 0);
	roiManager("Rename", "LHb LEFT");
	roiManager("Deselect");

	// Select bounds for the Right LHb
	setTool("polygon");
	waitForUser("Select bounds for the Right LHb. Click OK to continue.");
	roiManager("Add");
	roiManager("Select", 1);
	roiManager("Rename", "LHb RIGHT");
	roiManager("Deselect");

	// Combine right and left LHb boundaries
	roiManager("Select", newArray(0, 1));
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", 2);
	roiManager("Rename", "LHb COMBINED");


	// Select Left THALAMUS control bounds
	roiManager("Select", 0);
	waitForUser("Drag boundary to select control thalamic region on the left. Click OK to continue.");
	roiManager("Add");
	roiManager("Select", 3);
	roiManager("Rename", "Thalamus LEFT");
	roiManager("Deselect");


	// Select Right THALAMUS control bounds
	roiManager("Select", 1);
	waitForUser("Drag boundary to select control thalamic region on the right. Click OK to continue.");
	roiManager("Add");
	roiManager("Select", 4);
	roiManager("Rename", "Thalamus RIGHT");
	roiManager("Deselect");

	// Combine right and left THALAMUS boundaries
	roiManager("Select", newArray(3, 4));
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", 5);
	roiManager("Rename", "Thalamus COMBINED");

	// Close blue channels
	close(blueWindow);
	selectWindow(redWindow);
	run("Red");
	
	
//
// Part 2: SAVE FLUORESCENCE MEASUREMENTS
//	

	n = roiManager("count");

for (i = 0; i < n; i++) {
	roiManager("Select", i);
	run("Set Measurements...", "area mean integrated redirect=None decimal=5");
	run("Measure"); // Actually perform the measurements
}

	n = nResults;

	// Create or open the Results Table
	rt = Table.create("TempResults");

for (i = 0; i < n; i++) {

	// Get measurement results (Area, IntDen, RawIntDen) 
    roiName = RoiManager.getName(i);
	area = getResult("Area", i); // Area value
	mean = getResult("Mean", i); // Mean value
	intDen = getResult("IntDen", i); // Integrated Density value
	rawIntDen = getResult("RawIntDen", i); // Raw Integrated Density value

	// Add results in a **single row**
    rowIndex = Table.size("TempResults"); // Get current size of TempResults
    Table.set("Rat ID", rowIndex, Rat_ID); // Add Rat ID
    Table.set("Slice Number", rowIndex, Slice_Number); // Add Slice Number 
    Table.set("LHb Hemisphere", rowIndex, roiName); // Add Slice Number 
    Table.set("Area", rowIndex, area);      // Add Area
	Table.set("Mean", rowIndex, mean);      // Add Mean
	Table.set("IntDen", rowIndex, intDen);  // Add Integrated Density
	Table.set("RawIntDen", rowIndex, rawIntDen); // Add Raw Integrated Density
 }

	Table.rename("TempResults","Results");

	run("Read and Write Excel", "no_count_column file=\\EnterROIPathHere\\excel.xlsx sheet=SheetName stack_results"); 
	
	ROIPath = "\\EnterROIPathHere\\"; // Adjust this to your desired path

	roiManager("Deselect");
	roiManager("Save", ROIPath + "/" + currentName + "_ROIs.zip");	
	
	
	// clear everything so it doesn't mess up your next run through
	roiManager("Deselect");
	roiManager("Reset");			 // Clear the ROI Manager 
	run("Close All");                // Close all open images
	run("Clear Results");            // Close the Results panel
	
	print("Finished!");
	

