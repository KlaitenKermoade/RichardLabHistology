// Principal Image Exclusion Workflow, Based on Post-Thresholding Fluorescence 
	// finished by Klaiten Kermoade 3/28/25
	// This script is intended to batch through images in a given folder and exclude them from analysis based on deviation from thresholding. 
	// It will prompt user to enter and input image folder, then will prompt the user to select an output folder. 
	// In the output folder, the program will store PNG images of the red and green images that are within the range or outside of the range.
	// That range is determined by a median absolute deviation (MAD) function, a suitable range detection system maximally resistant to outliers. 
	// It will also save a text file pasting the list of outliers, and an excel with the outlier (exclusion) status of each image.
	// Thresholds from all images are set before analysis with the TRIANGLE threshold pattern, which I decided by eye to be the best default pattern

	// There are two options for thresholding; AUTO or MANUAL. Each method could be viable: 
	// "A manual threshold is appropriate if you want explicit control over things.
	// It is less tolerant of changes to your image such as a reduction in intensity for whatever reason.
	// By comparison, automatic thresholding is more tolerant of changes but may bring out details that would have otherwise been excluded by manual thresholding.
	// There is no right way or wrong way to this - you just need to be clear on what the effect is with each method and then understand what this can mean for your analysis.
	// The best way to understand that is to try both methods and see which one makes the most sense."
	// https://forum.image.sc/t/should-i-use-auto-threshold-provided-by-the-3d-object-counter-plugin-or-use-a-fixed-manual-one/108706

	// Thus, it's good measure to test out both and see if there are major differences. 

	// for AUTO, you just use this line of code: 
	// setAutoThreshold("Triangle dark"); // Apply Triangle thresholding method

	// for MANUAL, you use these lines of code: 
	// setAutoThreshold("Triangle dark"); 
	// setThreshold(X, 65535, "raw"); 
	// where X = a user-defined minimum value. 
	// To determine that value, I first run through all the images and set an AUTO threshold, collecting the minimum value that FIJI auto thresholds it to. 
	// We then took the average for each cohort for red channel and green channel. 


//
// Part 0: SET BATCH DIRECTORIES
// Note - INPUT folder of images you want to compare fluorescence intensities across; my images captured DAPI, FITC, and TRITC signal. This script will measure differences over the green and red channels.  
// Note - OUTPUT folder - a user declared folder where exclusion information will be stored 
//

	//BATCHING INPUT: SELECT a directory of images to open
	input = getDirectory("BATCH INPUT");
	//BATCHING OUTPUT: SELECT a directory of images to save within
	output = getDirectory("BATCH OUTPUT");
	print(output);

	//get list of files in INPUT folder 
	list = getFileList(input);

	// Declare function to delete all files in a directory - will use later
function deleteFilesInFolder(folder) {
	if (File.exists(folder)) {
	    fileList = getFileList(folder);
	        for (i = 0; i < fileList.length; i++) {
	            File.delete(folder + fileList[i]);
	        }
	}
}

	// CREATE subfolders for "Within_Range" and "Outliers"
	withinRangeRedFolder = output + "Within_Range_RED/";
	outliersRedFolder = output + "Outliers_RED/";
	withinRangeGreenFolder = output + "Within_Range_GREEN/";
	outliersGreenFolder = output + "Outliers_GREEN/";
	
	// Delete old files if folders exist
	deleteFilesInFolder(withinRangeRedFolder);
	deleteFilesInFolder(outliersRedFolder);
	deleteFilesInFolder(withinRangeGreenFolder);
	deleteFilesInFolder(outliersGreenFolder);

	// Ensure directories exist
	File.makeDirectory(withinRangeRedFolder);
	File.makeDirectory(outliersRedFolder);
	File.makeDirectory(withinRangeGreenFolder);
	File.makeDirectory(outliersGreenFolder);

	// INITIALIZE list for storing INTENSITY values
	AllNames = newArray();
	intensityValues = newArray();
	
	// INITIALIZE arrays for outliers and non-outliers
	OutliersValues = newArray();
	OutliersNames = newArray();
	nonOutliersValues = newArray();
	nonOutliersNames = newArray();
	
	setBatchMode(true); 

//
// STEP 1: loop through to declare array of ALL intensity values
//

	for(i = 0; i < list.length; i++) {
	
	// OPEN the next image in the batch
    open(input + list[i]);
	
	// Get the current image name
	currentName = getTitle();

	// Remove the ".tif" part from the file name
	baseName = currentName.substring(0, currentName.length - 4);

	rename(baseName);
	
	run("Split Channels");
	
	// set TRIANGLE threshold for Red channel
	selectImage("C3-" + baseName);
	setAutoThreshold("Triangle dark"); // Apply Triangle thresholding method
    // setThreshold(87.857, 65535, "raw");  // Turn on for manual thresholding of RED CHANNEL, FIRST HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/15 OR 12/16
    setThreshold(69.350, 65535, "raw");  // Turn on for manual thresholding of RED CHANNEL, SECOND HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/17
	run("Convert to Mask");
	run("Red");

    // MEASURE mean intensity of the entire image
	run("Set Measurements...", "area mean integrated redirect=None decimal=5");
    run("Measure");
        
	// Retrieve the integrated density value from the Results window
	intDen = getResult("IntDen", nResults - 1);

	AllNames = Array.concat(AllNames, baseName);
	intensityValues = Array.concat(intensityValues, intDen); // Adds it to the end of the array
		
    close(); // Close processed image
    }

		
//
// STEP 2: Use Robust Z-Scoring Method for Determining Limits - boundaries based on Median Absolute Deviation (MAD)
//
	
	// Calculate MEDIAN
	intensityValuesSORTED = Array.copy(intensityValues); // need to copy to SORTED, otherwise the pairing between intensityValues and baseName becomes incorrect
	intensityValuesSORTED = Array.sort(intensityValuesSORTED); 
	Array.print(intensityValuesSORTED);
	
	// Declare function to take median (yes, FIJI doesn't have a built in median command)
function median(x) {
    var mid = Math.floor(x.length / 2);  // Middle index
    if (x.length % 2 == 1) {  // If the length is odd
        return x[mid];  // Return the middle element
    } else {  // If the length is even
        return (x[mid - 1] + x[mid]) / 2;  // Average of the two middle elements
    }
}
	
	MEDIANvalue = median(intensityValuesSORTED);
	print("Median Value: " + MEDIANvalue);

	// Calculate MAD
function AbsoluteDeviations(x) {
  	var absDeviations = newArray();  // Initialize an array to store the absolute deviations; within the context of a new function you have to call this a variable "var"
  	for (var i = 0; i < x.length; i++) {
    	absDeviations[i] = Math.abs(x[i] - MEDIANvalue);  // Calculate the absolute deviation and store it in the array
    	absDeviations = Array.sort(absDeviations);
 	}
 	return absDeviations;  // Output the median of the absolute deviations 
}
	
	ABSDEVS = AbsoluteDeviations(intensityValues); // Calculate MAD using the defined median function
	Array.print(ABSDEVS);
	
	MADvalue = median(ABSDEVS);
	print("Uncorrected MAD Value = " + MADvalue);
	
	CorrectedMADvalue = MADvalue * 1.4826 ; // Correction constant assuming normality of the data disregarding the abnormalities of outliers; see Leys et al. 2013
	print("CORRECTED MAD Value = " + CorrectedMADvalue);
		

	// Calculate the robust Z-score (using MAD as the scale)
	
	lowerBound = MEDIANvalue - (3 * CorrectedMADvalue) ; // set 3 MAD values above and below the median as our bounds for declaring outliers; can change
	upperBound = MEDIANvalue + (3 * CorrectedMADvalue) ;
	
	print("Lower intensity (intDen) bound: " + lowerBound); 
	print("Upper intensity (intDen) bound: " + upperBound);

	nRows = intensityValues.length; 
	Results = newArray(nRows); // create a table called Outlier Analysis Red
	Table.reset("Results");
	Table.create("Results");
	
	Table.setColumn("Name", AllNames); // Add column headers
	Table.setColumn("Intensity", intensityValues);
	Table.setColumn("Outlier?", newArray(nRows)); 

	outliers = newArray(); // initialize a temporary outliers array
	
	// Determine outliers and populate the new table
for (i = 0; i < nRows; i++) {
    if (intensityValues[i] < lowerBound || intensityValues[i] > upperBound) {
        outliers[i] = "Yes";
    } else {
        outliers[i] = "No";
    }
}
	
	// Store outlier results in the new table
	Table.setColumn("Outlier?", outliers);

	// Show the final table
	Table.update();
		
	
//
// STEP 3: loop through again, and based on robust z-scoring method, SAVE in distinct folders
//	
	
	// LOOP through images again & save based on thresholding
for (i = 0; i < list.length; i++) {	
	
	// RE-OPEN the original image
    open(input + list[i]);

	// REMOVE the ".tif" part from the file name again
    baseName = list[i].substring(0, list[i].length - 4);
        
    rename(baseName);
        
    // SPLIT channels
    run("Split Channels");
        
    // SELECT the RED channel (C3)
    selectImage("C3-" + baseName);
        
    // APPLY Triangle thresholding
    setAutoThreshold("Triangle dark");
    // setThreshold(87.857, 65535, "raw");  // Turn on for manual thresholding of RED CHANNEL, FIRST HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/15 OR 12/16
    setThreshold(69.350, 65535, "raw");  // Turn on for manual thresholding of RED CHANNEL, SECOND HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/17
    run("Convert to Mask");
    run("Red");
        
  	// Check if the intensity value exceeds the MAD Z-score threshold (robust outlier detection)
	
	if (intensityValues[i] < lowerBound || intensityValues[i] > upperBound) {
	    // This value is an outlier, add to outliers array
		OutliersValues = Array.concat(OutliersValues, intensityValues[i]);
	    OutliersNames = Array.concat(OutliersNames, baseName);
	    newFileName = baseName + "-TRITHRESHOLD_outlier.png";
	    filePath = outliersRedFolder + newFileName;
	    saveAs("png", filePath);
	} else {
	    // This value is a non-outlier, add to non-outliers array
	    nonOutliersValues = Array.concat(nonOutliersValues, intensityValues[i]);
	    nonOutliersNames = Array.concat(nonOutliersNames, baseName);
	    newFileName = baseName + "-TRITHRESHOLD_withinrange.png";
	    filePath = withinRangeRedFolder + newFileName;
	    saveAs("png", filePath);
	}
	
}
	
	// language if you want to print these values in the log box
	print("Number of RED Non-Outliers: " + nonOutliersValues.length);
	print("Number of RED Outliers: " + OutliersValues.length);
	
	print("Red Non-Outlier Names:");
	Array.print(nonOutliersNames);
	print("RED Outlier Names:");
	Array.print(OutliersNames);
	
	print("RED Non-Outlier Values:");
	Array.print(nonOutliersValues);
	print("RED Outlier Values:");
	Array.print(OutliersValues);
		


// WRITE outlier results to an excel
run("Read and Write Excel", "file=" + output + "\\ExcelName.xlsx no_count_column sheet=RED dataset_label=RED stack_results"); 

// JOIN the outlier list into a single string
outlierLog = "outliers:\n";
for (i = 0; i < OutliersNames.length; i++) {
  outlierLog = outlierLog + OutliersNames[i] + "\n";  // Add each image name followed by a newline
}

// SAVE outlier list as a text file
File.saveString(outlierLog, output + "OutlierList_REDchannel.txt");


// PRINT confirmation
print("Red Channel Processing Complete! Non-outlier images saved in 'Within_Range_Red', outliers saved in 'Outliers_Red'.");
run("Close All"); // Close any remaining open images


// RE-INITIALIZE list for storing INTENSITY values
AllNames = newArray();
intensityValues = newArray();

// RE-INITIALIZE arrays for outliers and non-outliers
OutliersValues = newArray();
OutliersNames = newArray();
nonOutliersValues = newArray();
nonOutliersNames = newArray();


//
// STEP 4: same as step 1, but for GREEN channel
//

for(i = 0; i < list.length; i++) {
	
	// OPEN the next image in the batch
    open(input + list[i]);
	
	// Get the current image name
	currentName = getTitle();

	// Remove the ".tif" part from the file name
	baseName = currentName.substring(0, currentName.length - 4);

	rename(baseName);
	
	run("Split Channels");
	
	// set TRIANGLE threshold for GREEN channel
	selectImage("C2-" + baseName);
	setAutoThreshold("Triangle dark"); // Apply Triangle thresholding method
	// setThreshold(204.238, 65535, "raw");  // Turn on for manual thresholding of GREEN CHANNEL, FIRST HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/15 OR 12/16
    setThreshold(104.775, 65535, "raw");  // Turn on for manual thresholding of GREEN CHANNEL, SECOND HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/17
	run("Convert to Mask");
	run("Green");

    // MEASURE mean intensity of the entire image
	run("Set Measurements...", "area mean integrated redirect=None decimal=5");
    run("Measure");
        
	// Retrieve the integrated density value from the Results window
	intDen = getResult("IntDen", nResults - 1);

	AllNames = Array.concat(AllNames, baseName);
	intensityValues = Array.concat(intensityValues, intDen); // Adds it to the end of the array
		
    close(); // Close processed image
}

		
//
// STEP 5: SAME AS STEP 2, BUT FOR GREEN 
//
	
	// Calculate MEDIAN
	intensityValuesSORTED = Array.copy(intensityValues); // need to copy to SORTED, otherwise the pairing between intensityValues and baseName becomes incorrect
	intensityValuesSORTED = Array.sort(intensityValuesSORTED); 
	Array.print(intensityValuesSORTED);
	
	MEDIANvalue = median(intensityValuesSORTED);
	print("Median Value: " + MEDIANvalue);

	ABSDEVS = AbsoluteDeviations(intensityValues); // Calculate MAD using the defined median function
	Array.print(ABSDEVS);
	
	MADvalue = median(ABSDEVS);
	print("Uncorrected MAD Value = " + MADvalue);
	
	CorrectedMADvalue = MADvalue * 1.4826 ; // Correction constant assuming normality of the data disregarding the abnormalities of outliers; see Leys et al. 2013
	print("CORRECTED MAD Value = " + CorrectedMADvalue);
		

	// Calculate the robust Z-score (using MAD as the scale)
	
	lowerBound = MEDIANvalue - (3 * CorrectedMADvalue) ; // set 3 MAD values above and below the median as our bounds for declaring outliers; can change
	upperBound = MEDIANvalue + (3 * CorrectedMADvalue) ;
	
	print("Lower intensity (intDen) bound: " + lowerBound); 
	print("Upper intensity (intDen) bound: " + upperBound);
	

	nRows = intensityValues.length; 
	Results = newArray(nRows); // create a table called Outlier Analysis Red
	Table.reset("Results");
	Table.create("Results");
	
	Table.setColumn("Name", AllNames); // Add column headers
	Table.setColumn("Intensity", intensityValues);
	Table.setColumn("Outlier?", newArray(nRows)); 

	outliers = newArray(); // initialize a temporary outliers array
	
	// Determine outliers and populate the new table
for (i = 0; i < nRows; i++) {
    if (intensityValues[i] < lowerBound || intensityValues[i] > upperBound) {
        outliers[i] = "Yes";
    } else {
        outliers[i] = "No";
    }
}
	
	// Store outlier results in the new table
	Table.setColumn("Outlier?", outliers);

	// Show the final table
	Table.update();
		
			
	
//
// STEP 6: SAME AS STEP 3, BUT FOR GREEN 
//	
	
	// LOOP through images again & save based on thresholding
for (i = 0; i < list.length; i++) {	
	
	// RE-OPEN the original image
    open(input + list[i]);

	// REMOVE the ".tif" part from the file name again
    baseName = list[i].substring(0, list[i].length - 4);
        
    rename(baseName);
        
    // SPLIT channels
    run("Split Channels");
        
    // SELECT the GREEN channel (C2)
    selectImage("C2-" + baseName);
        
    // APPLY Triangle thresholding
    setAutoThreshold("Triangle dark");
    // setThreshold(204.238, 65535, "raw");  // Turn on for manual thresholding of GREEN CHANNEL, FIRST HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/15 OR 12/16
    setThreshold(104.775, 65535, "raw");  // Turn on for manual thresholding of GREEN CHANNEL, SECOND HALF - based on average for COHORT 4 IMAGES TAKEN ON 12/17
    run("Convert to Mask");
    run("Green");
        
  	// Check if the intensity value exceeds the MAD Z-score threshold (robust outlier detection)
	
 	if (intensityValues[i] < lowerBound || intensityValues[i] > upperBound) {
	    // This value is an outlier, add to outliers array
		OutliersValues = Array.concat(OutliersValues, intensityValues[i]);
	    OutliersNames = Array.concat(OutliersNames, baseName);
	    newFileName = baseName + "-TRITHRESHOLD_outlier.png";
	    filePath = outliersGreenFolder + newFileName;
	    saveAs("png", filePath);
	} else {
	    // This value is a non-outlier, add to non-outliers array
	    nonOutliersValues = Array.concat(nonOutliersValues, intensityValues[i]);
	    nonOutliersNames = Array.concat(nonOutliersNames, baseName);
	    newFileName = baseName + "-TRITHRESHOLD_withinrange.png";
	    filePath = withinRangeGreenFolder + newFileName;
	    saveAs("png", filePath);
	  }
		
	}
	
	// language if you want to print these values in the log box
	print("Number of Green Non-Outliers: " + nonOutliersValues.length);
	print("Number of Green Outliers: " + OutliersValues.length);
	
	print("Green Non-Outlier Names:");
	Array.print(nonOutliersNames);
	print("Green Outlier Names:");
	Array.print(OutliersNames);
	
	print("Green Non-Outlier Values:");
	Array.print(nonOutliersValues);
	print("Green Outlier Values:");
	Array.print(OutliersValues);
		

// WRITE outlier results to an excel
run("Read and Write Excel", "file=" + output + "\\ExcelName.xlsx no_count_column sheet=GREEN dataset_label=GREEN stack_results"); 

// SAVE outlier list as a text file
File.saveString(outlierLog, output + "OutlierList_GREENchannel.txt");

// PRINT confirmation
print("Green Channel Processing Complete! All Done! Non-outlier images saved in 'Within_Range_Green', outliers saved in 'Outliers_Green'.");
run("Close All"); // Close any remaining open images



