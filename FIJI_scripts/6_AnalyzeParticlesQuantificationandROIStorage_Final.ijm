// Automated Puncta Quantification - Inside a Targeted Square ROI
	// finished by Klaiten Kermoade 9/17/2026
	// 
	// This script functions as so:
	// 1) Load Image
	// 2) Extract metadata from image name (optional, see below for my specific naming style)
	// 3) Toggle designated ROI square over target area in image; save target ROI
	// 4) Subtract background, analyze particles (based on overall fluorescence) within target ROI; save puncta count within ROI
	// 5) Save data for each particle (circularity, area, etc.)
	// 6) Save boundaries for each particle as individual ROIs
//
// Parts 1-3: rename, extract metadata, place & save target ROI
//

	roiManager("Deselect");	
	roiManager("Reset");			 // Clears the ROI Manager 
	run("Clear Results");            // Closes the Results panel
		
	// Get the current image name
	baseName = getTitle();
	
	// Remove the ".tif" part from the file name
	currentName = baseName.substring(0, baseName.length - 4);
	rename(currentName);
	
	// Extract clause with Rat ID & slice number - based on my image names; for this group, I started image title with "IDx-y-Z", where PWx is the rat ID #, y is the slice number, and Z is L or R (hemisphere)
	splitName = split(currentName, " ");
	
	// The first part contains Rat_ID and Slice_Number joined by "-"; split along the hyphen and take each half  
	Array.print(splitName);
	firstClause = splitName[0];
	subSplit = split(firstClause, "-");
	Array.print(subSplit);
	Rat_ID = subSplit[0];  
	Slice_Number = subSplit[1];
	Hemisphere = subSplit[2];
			
	selectWindow(currentName);
	
	// Select bounds for the VP 
	setTool("rectangle");
	makeRectangle(666.667, 666.667, 1500, 1500); // can change these coordinates/size as needed based on your image
	waitForUser("Select bounds for the VP. Click OK to continue.");
	roiManager("Add");
	roiManager("Select", 0);
	roiManager("Rename", "VP");

	// Save these ROIs first; ensure folder exists 
	ROIPath = "\\EnterROIFolderPathHere\\";
	roiManager("Save Selected", ROIPath + "/" + currentName + "_ROIs.zip");
	roiManager("Deselect");
	
//
// Part 4: Run Background Subtraction, Median Filtering, and MaxEntropy Thresholding; analyze particles; count & save puncta
//

	selectWindow(currentName);
	
	// VP Quantification
	run("Split Channels");

	// Construct channel window names dynamically
	redWindow = currentName + " (red)";
	greenWindow = currentName + " (green)";
	blueWindow = currentName + " (blue)";

	// Get rid of green channel & choose the DAPI channel, from which regions will be constructed
	close(greenWindow);
	close(blueWindow);
	
	// Run Background Subtraction, Median Filtering, and MaxEntropy Thresholding
	selectWindow(redWindow);
	run("Red");
	run("Subtract Background...", "rolling=50");
	run("Median...", "radius=4");
	setAutoThreshold("MaxEntropy dark");
	call("ij.plugin.frame.ThresholdAdjuster.setMode", "B&W");
	

    // Create or open the TempResults Table
 	rt = Table.create("TempResults");

	nRois = roiManager("count");
for (r = 0; r < nRois; r++) {
   
   // Select the ROI
    roiManager("Select", r);
    roiName = RoiManager.getName(r);  // Store ROI name ONCE
    
    // Run Analyze Particles for this ROI
    run("Analyze Particles...", "size=0.001-0.055 circularity=0.60-1.00 show=Overlay display exclude summarize");
 
  	Count          = Table.get("Count", r);
  	TotalArea      = Table.get("Total Area", r);
    AvgSize        = Table.get("Average Size", r);
    PercentArea    = Table.get("%Area", r);
    AvgCircularity = Table.get("Circ.", r);
    AvgSolidity    = Table.get("Solidity", r);
    
    selectWindow("TempResults");
    rowIndex = Table.size("TempResults");
    Table.set("Rat_ID", rowIndex, Rat_ID, "TempResults");
    Table.set("Slice_Number", rowIndex, Slice_Number);
    Table.set("Region", rowIndex, roiName); 
    Table.set("Hemisphere", rowIndex, Hemisphere);    
    Table.set("Count", rowIndex, Count);
    Table.set("TotalArea", rowIndex, TotalArea);
    Table.set("PercentArea", rowIndex, PercentArea);
    Table.set("AvgSize", rowIndex, AvgSize);
    Table.set("AvgCircularity", rowIndex, AvgCircularity);
    Table.set("AvgSolidity", rowIndex, AvgSolidity);
}

	Table.rename("TempResults","Results");

	run("Read and Write Excel", "no_count_column file=\\EnterPathHere\\EnterFirstExcelNameHere.xlsx sheet=EnterSheetName stack_results"); 


//
// Part 5: Re-analyzes particles, but save data from each specific loci into a separate excel sheet
//
	
	selectWindow(redWindow);
    
    run("Clear Results");            // Clear the Results panel for the next iteration
    
	rt = Table.create("TempResults");

for (r = 0; r < nRois; r++) {
   
    // Select the ROI
    roiManager("Select", r);
    roiName = RoiManager.getName(r);  // Store ROI name
    
    // Run Analyze Particles for this ROI
    run("Analyze Particles...", "size=0.001-0.055 circularity=0.60-1.00 show=Overlay display exclude summarize");

 	nParticles = nResults;  // Number of particles detected
       
for (p = 0; p < nParticles; p++) {
    // Get particle measurements
    area        = getResult("Area", p);
    X_Coord     = getResult("BX", p);
    Y_Coord     = getResult("BY", p);
    width       = getResult("Width", p);
    height      = getResult("Height", p);
    Circularity = getResult("Circ.", p);
    AspectRatio = getResult("AR", p);
    Roundness   = getResult("Round", p);
    Solidity    = getResult("Solidity", p);
        
    // Add results in a new row
    selectWindow("TempResults");
    rowIndex = Table.size("TempResults");
    Table.set("Rat_ID", rowIndex, Rat_ID);
    Table.set("Slice_Number", rowIndex, Slice_Number);
    Table.set("Region", rowIndex, roiName); 
    Table.set("Area", rowIndex, area);
    Table.set("X_Coord", rowIndex, X_Coord);
    Table.set("Y_Coord", rowIndex, Y_Coord);
    Table.set("Width", rowIndex, width);
    Table.set("Height", rowIndex, height);
    Table.set("Circularity", rowIndex, Circularity);
    Table.set("AspectRatio", rowIndex, AspectRatio);
    Table.set("Roundness", rowIndex, Roundness);
    Table.set("Solidity", rowIndex, Solidity);
  
    }
    
   	run("Clear Results");            // Clear the Results panel for the next iteration
}

	Table.rename("TempResults","Results");
	run("Read and Write Excel", "no_count_column file=\\EnterPathHere\\EnterSecondExcelNameHere.xlsx sheet=SheetName stack_results"); 
	        
//
// Part 6: save individual loci as a combined ROI group     
//
	
	// Combine all boundaries
   	roiManager("Select", 0);
	run("Analyze Particles...", "size=0.001-0.055 circularity=0.60-1.00 show=Overlay display exclude summarize add");
	  
   	roiManager("Select", 0);
	roiManager("Delete");
   	   	
	roiCount = roiManager("count");
	allIndices = newArray(roiCount); // Build an array of indices [0,1,2,...,roiCount-1]
	
for (i = 0; i < roiCount; i++) {
    allIndices[i] = i;
    roiManager("Select", i);
    CellNumber = i + 1;
    roiManager("Rename", "Cell " + CellNumber);
}
			
	// Select all ROIs & combine them
	roiManager("Select", allIndices);
  	roiManager("Combine");
  	roiManager("Add");  	
  	roiManager("Select", roiCount); // select the combined ROI, which will be at the position roiCount (since only 1 ROI was added)
    roiManager("Rename", "All cFos Loci");
    
    roiManager("Save", ROIPath + "/" + currentName + "_AllcFosLoci.zip");

    
	// CLOSE everything for the next run
	roiManager("Deselect");
	roiManager("Reset");    // Clears the ROI Manager 
	run("Close");			// Closes active non-image windows
	close();                // Closes active image panel
	run("Clear Results");   // Clears results
		
	print("Finished!");