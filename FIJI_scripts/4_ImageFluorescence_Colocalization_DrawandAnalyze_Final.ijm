// Green/Red Channel Colocalization Quantification 
	// Finished by Klaiten Kermoade 3/22/25	
	
	// This script is intended to analyze overlap between fluorescent signal within a user-defined boundary (usually, cells).
	// There are essentially 5 steps: 
	// 1. Load image 
	// 2. Define boundaries of cells to set as ROIs 
	// 3. Threshold pixels 
	// 4. Count color pixels within each cell and overall 
	// 5. save defined ROIs, and save an excel of pixel results 
	
	// This script is most helpful when the user has a small subpopulation of cells imaged (i.e., max 20 per slice and usually much fewer).
	// Definition of cell borders is not automated and thus both a) susceptible to user error and b) annoying.
	// I tried to automate the cell selection process, but it just seemed too inaccurate for me to be comfortable as boundaries for cells. May try it again later.
	// So, overall, if you use this, try to be blinded to groups, and try to have as strict rules for setting boundaries as possible.
		
	
	// The user needs to change multiple things here for their purpose, including: 
	// 1. "baseName" - I made this command to distill information from an image file into a more succinct name. You may not need this at all. 
	// --> one note on this however is that your name must contain no spaces for the Excel writing process to happen properly (i.e., full name will get cut off in a results tab because of spaces)
	// --> thus, at the very least, you should change your current name to exclude spaces
	// 2. Thresholding indices - you must look through your images and define your own thresholds to suit your purposes across the green and  red channels. 
	// 3. Paths for saving ROI index, and within the writexl function. My paths are very specific and I will even change these between cohorts.
	
	
	// There is a portion here where a user may want to alter values based on their images is this line for both the red and green channels: 
	// setThreshold(X, 65535, "raw"); 
	// where X = a user-defined minimum value. 
	// To determine that value, I first run through all the images and set an AUTO threshold, collecting the minimum value that FIJI auto thresholds it to. 
	// We then took the average for each cohort for red channel and green channel. That number became the new X value. 
	
	
	// Finally, IF YOU WANT TO BATCH THROUGH A BUNCH OF IMAGES - I probably wouldn't for this particular set since there is
	// so much user interaction and possibility for error - some shell commands are printed here which can be enacted
	//SELECT a directory of images to open
		//// input = getDirectory("BATCH INPUT");
	//open a dialogue to select location where images will be stored
		//// output = getDirectory("BATCH OUTPUT");
	//get list of files in folder 
		//// list = getFileList(input);
		//// setBatchMode(true); 
			
	// for(i = 0; i < 1000; i++) {
	
	run("Clear Results");  // Clear the Results panel
	
	
//
// Part 0: extracting metadata from image file name
// Note - my file names looked like "241127 KEK29 postVP 3r 20x2z 3x3 gal-Stitched - Denoised-BC" - that is "date", "Rat ID","approx A/P", "region" (i.e., here ventral pallidum),  
// , "slice number", "hemisphere" (i.e., r = right), "maginification" (i.e., 20x + 2x zoom), "image tiling", "image type" (i.e., ggalvano) 
// Note - many variables are named with the intention of use in the VP
//
			
	// Get the current image name
	currentName = getTitle();
	
	// Remove the ".tif" part from the file name, replace spaces with underscores, delete underscore that follows abberantly
	baseName = currentName.substring(0, currentName.length - 4);
	baseName = replace(baseName, " ", "_");
	
	// Rename image name as the shorter baseName version
	rename(baseName);
	

//
// Part 1: DRAW ROIs
// Note - user draws around each mCherry positive cell body in the red channel 
//
	
	// Split Channels
	run("Split Channels");

	// Get rid of DAPI channel
	selectImage("C1-" + baseName);
	close("C1-" + baseName);
	
	// Start loop for ROI selection
while (true) {
	
	// Set the tool to Segmented Line
    setTool("polygon");
    
    // Store initial ROI count before user action
    initialRoiCount = roiManager("count");

    // Pause the script to allow the user to draw an ROI
	waitForUser("Draw all ROIs. Choose segmented line and apply around all cells. Finish each cell by clicking over the initial point. Click OK to continue.");
	
	// Check if a selection exists before adding to ROI Manager
	if (selectionType() == -1) { 
        // No selection was made, exit the loop
        break;
	}
    
	// **TEMPORARILY add ROI to detect user input**
    run("ROI Manager...");
    roiManager("Add");
    
    // Check if the user actually drew an ROI
    newRoiCount = roiManager("count");
    
  	if (newRoiCount == initialRoiCount) {
        // No new ROI was added, meaning the user canceled
        break;
  	}

    // Remove the temporarily added ROI
    roiManager("Select", roiManager("count") - 1);
    roiManager("Delete");

    // If an ROI was drawn, process it
  	if (newRoiCount > initialRoiCount) {
        
        // Add the convex hull ROI to the ROI Manager
        roiManager("Add");

        // Immediately remove the overlay so the next ROI is drawn cleanly
        roiManager("Deselect");
        run("Select None");
  	}
}

    // Proceed with the rest of the script after the user is done adding ROIs
	print("User has finished adding ROIs. Continuing...");

	// After the user finishes drawing ROIs, continue with the rest of the script
	// You can now access the ROIs and continue processing them as needed
	
	// Get the total number of ROIs in the ROI Manager
	n = roiManager("Count");
	
	// Loop through each ROI and rename it
for (i = 0; i < n; i++) {
	
    roiManager("Select", i); // Select ROI
    roiManager("Rename", "cell " + (i+1)); // Rename to "cell 1", "cell 2", etc
}
	

//
// Part 2: QUANTIFY COLOCALIZATION
// Note - user should change thresholding criteria to fit own dataset - setThreshold(... 
//
	
	// set TRIANGLE threshold for Red channel
	selectImage("C3-" + baseName);
	setAutoThreshold("Triangle dark"); // Apply Triangle thresholding method
	setThreshold(250, 65535, "raw");   //  NOTE: 250 = a user-derived minimum value. see above note. 
	run("Convert to Mask");
	run("Fill Holes");  // Fill any holes in the binary mask
	run("Red");

	// set TRIANGLE threshold for Green channel
	selectImage("C2-" + baseName);
	setAutoThreshold("Triangle dark"); // Apply Triangle thresholding method
	setThreshold(300, 65535, "raw");   //  NOTE: 300 = a user-derived minimum value. see above note. 
	run("Convert to Mask");
	run("Fill Holes");  // Fill any holes in the binary mask'
	run("Green");
	
	
    // MERGE THRESHOLDED channels
    run("Merge Channels...", "c1=[C2-" + baseName + "] c2=[C3-" + baseName + "] create");
	
	roiManager("Combine"); // Combines all ROIs into one
	roiManager("Add"); // Adds the combined ROI to the ROI Manager
	roiManager("Select", roiManager("Count")-1); // Selects the last added ROI
	roiManager("Rename", "ALL CELLS COMBINED"); // Rename the last (combined) ROI as "all cells combined"
	run("Clear Outside"); // Clears everything outside the selected ROI
	
	run("RGB Color"); // Converts the image to RGB color
	
	// Loop through each ROI, starting with individual cells, and ending with the combined total. The resultant excel 
	// won't specify which is which, but the final one will always be the combined ROI
	
	n = roiManager("Count");

for (i = 0; i < n; i++) {
   
   // Select ROI i
    roiManager("Select", i);
    
    // Run Color Pixel Counter for different colors
    run("Color Pixel Counter", "color=Red display both"); 
    run("Color Pixel Counter", "color=Green display both"); 
    run("Color Pixel Counter", "color=Yellow display both"); 
}
	
	// Get user-selected directory for ROIs
	ROIPath = "\\EnterROIPathHere\\";
	File.makeDirectory(ROIPath);

	// Save all ROIs to a .zip file in the new folder
	roiManager("Deselect");
	roiManager("Save", ROIPath + "/" + baseName + " - ROIs.zip");
		
	// Write and save results to an excel file. This command will make a new tab named "baseName" within your excel, and will write "baseName" at the top of each sheet
	run("Read and Write Excel", "file=\\EnterExcelPathHere\\ExcelName.xlsx sheet=" + baseName + " dataset_label=" + baseName); 
	
	// clear everything so it doesn't mess up your next run through
	roiManager("Deselect");
	roiManager("Reset");			 // Clear the ROI Manager 
	run("Close All");                // Close all open images
	run("Clear Results");            // Close the Results panel
	
	print("Finished! ROIs saved, Results saved.");
	
	
	
	