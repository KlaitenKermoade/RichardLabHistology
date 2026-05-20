// Atlas Alignment Regional Sublocalization - Characterization of BF-to-LHb fluorescently-labeled neurons 
	// finished by Klaiten Kermoade 11/24/2025
	
	// Functionally this script closes the gap between atlas alignment and distinguishing regional sublocalization of cells targeted with surgery.
	// This was initially targeted for working with 20x 5x7 images within the Ventral Pallidum. I used a viral approach attempting to target VP-to-LHb neurons with mCherry-labeled viruses (either Gq or Gi, or just mCherry).
	// This script requires two images: 1) an actual image of the brain and 2) an atlas alignment image that was created through a QUINT-based method. Note that images from the QUINT-based method will not be correctly sized - this script will resize them properly.
	// This script also requires ROIs from previous manual segmentation steps in FIJI using multipoint selection - see "CellCounting_InsideandOutsideROI_Final.ijm", which is how these ROIs will be stored
	// This was specifically designed for use with the Calabrese rat P80 atlas (https://scalablebrainatlas.incf.org/rat/CBWJ13_age_P80) - so use with other atlases may not work as designed. 
	// Image names were named like "KEK4 midVPl sp 20x 5x7" - that is "Rat ID", "approx A/P", "region" (i.e., here ventral pallidum), "hemisphere", "IHC type" (i.e., here substance P), "maginification" and "image tiling". Important for metadata extraction within script.
	
	// We have a 6 part process here where the script will:
	// 1. After initializing the images, uses the "Label images to ROIs" function through the BIOP plugin (which may need to be downloaded). The command pulls: Plugins --> BIOP --> Image Analysis --> Label image to ROIs
	// 1.5. If necessary (as often is) - once too far posterior, the atlas we used did not distinguish subregions within the "Pallidum" - that is, the VP and Globus Pallidus are pooled. Here, we manually draw a line intersecting the Anterior Commisure to force a bisection between these two regions, if needed.
	// 2. Find each unique ROI name (based on color) - if a region is separated into two different areas on the atlas image, they will both be called the same thing
	// 3. Find the indices within the ROI list where each unique ID is located
	// 4. Combine unique ROIs
	// 5. Delete non-combined ROIs (while keeping in the AC boundary, if calculated)
	// 6. Assign each ROI name to a meaningful region name with a user-defined key, pull in previously selected cells from another ROI list, and then loop through each cell selection and distinguish which region the cell exists within. 
	
	// Refer to this github to download PTBIOP, if needed: https://github.com/BIOP/ijp-LaRoMe/blob/master/README.md
	// Much of the script is dedicated to calculating the separation between the VP and the GP. 
	
		
	run("Clear Results");            // Close the Results panel
	roiManager("deselect");
	roiManager("Reset");	         // Clear ROI manager
	
	
// Part 0                                //
// Initialize images used for processing //
//                                       //

//
waitForUser("Select the image of interest. Click OK to continue.");
//

	// Get the current image name
	currentName = getTitle();
	
	// Remove the ".tif" part from the file name, replace spaces with underscores, delete underscore that follows abberantly
	baseName = currentName.substring(0, currentName.length - 4);
	baseName = replace(baseName, " ", "_");
	rename(baseName);
	
	Width = getWidth();
	Height = getHeight(); 
	
// Extract hemisphere (should work for pretty much all the images)	
	VPPos = indexOf(baseName, "VP");
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
waitForUser("Select the atlas image. Click OK to continue.");	
//

	// Set proportions to mirror image; processing up to this point descales axes.
	run("Scale...", "x=- y=- width=" + Width + " height=" + Height + " interpolation=None create");
	
	
	// Run the script to draw boundaries around regions
	run("Label image to ROIs");

	// Create a dictionary to store grouped ROIs
	roiNumbers = newArray();
	roiGroups = newArray();
	uniqueNumbers = newArray();

	n = roiManager("count");
	
	 
// Part 1                               //
// Create an array of all the ROI names //
//                                      //

	// Iterate through ROIs to create comprehensive ROI list
for (i = 0; i < n; i++) {
    roiManager("select", i);
    name = RoiManager.getName(i);
    
    // Extract the number after " - ID "
	parts = split(name, " - ID ");
	if (lengthOf(parts) > 1) {
    id_number = parts[1]; // This gives the number after " - ID "
	} else {
    id_number = "Unknown"; // Fallback in case of unexpected naming
	} 	
	roiNumbers[i] = id_number; // Store the extracted ID number at index i in roiNumbers
}

	// Sanity check - print all ROI numbers
	Array.print(roiNumbers);
	

// Part 1.5                                                       //
// If AC is split (at posterior sections), split VP and EGP       //
//                                                                //


	// Arrays to hold the AC ROI coordinates separately
	xAC1 = newArray();
	yAC1 = newArray();
	xAC2 = newArray();
	yAC2 = newArray();

	acCount = 0;
	
	// Iterate through ROIs to find position of anterior commissure, and print out the (1) or (2) sets of coordinates where it exists

	// Arrays to store AC ROI indices + their areas
	acIndices = newArray();
	acAreas   = newArray();

	// Loop through all ROIs in the ROI Manager
for (i = 0; i < n; i++) {
    name = RoiManager.getName(i);
    // Find all ROIs whose name contains the AC key
    if (indexOf(name, "10354432") != -1) {
        roiManager("select", i);
        getStatistics(area);   // measure area
        if (area >= 5000) {
            acIndices = Array.concat(acIndices, i);
            acAreas   = Array.concat(acAreas, area);
        }
    }
}

	// Sort by area (descending)
if (acIndices.length > 1) {
    Array.sort(acAreas, acIndices);  // ascending order
    Array.reverse(acAreas);          // now descending
    Array.reverse(acIndices);
}
	
	Array.print(acAreas); 
	
	// Extract coordinates
	acCount = acIndices.length;

	// Initialize variables so they always exist
	xAC1 = newArray();
	yAC1 = newArray();
	xAC2 = newArray();
	yAC2 = newArray();

	// If there is at least ONE AC ROI
if (acCount >= 1) {
    roiManager("select", acIndices[0]);
    getSelectionCoordinates(xAC1, yAC1);
}

// If there is a SECOND AC ROI
if (acCount >= 2) {
    roiManager("select", acIndices[1]);
    getSelectionCoordinates(xAC2, yAC2);
}

	// Debug output
	print("AC ROIs found: " + acCount);

	Array.print(xAC1);
	Array.print(yAC1);
	Array.print(xAC2);
	Array.print(yAC2);

	// Proceed only if we found two AC ROIs
	if (acCount >= 2) {
    // Get min/max X for each AC ROI
    Array.getStatistics(xAC1, min1, max1, mean, stdDev);
    Array.getStatistics(xAC2, min2, max2, mean, stdDev);

    // If AC1 is to the left of AC2, max1 will be less than min2; otherwise, it is to the right of AC2
    if (max1 < min2) {
        // Find y for max1 in AC1
        for (i = 0; i < lengthOf(xAC1); i++) {
            if (xAC1[i] == max1) {
                y1 = yAC1[i];
                break;
            }
        }
        // Find y for min2 in AC2
        for (i = 0; i < lengthOf(xAC2); i++) {
            if (xAC2[i] == min2) {
                y2 = yAC2[i];
                break;
            }
        }
        // Draw line from (max1, y1) to (min2, y2)
        makeLine(max1, y1, min2, y2);
        roiManager("Add");  // Add line to ROI Manager
        roiManager("select", roiManager("count") - 1);
        roiManager("Rename", "Theoretical AC Boundary");
        
       } else {
        // Find y for min1 in AC1
        for (i = 0; i < lengthOf(xAC1); i++) {
            if (xAC1[i] == min1) {
                y1 = yAC1[i];
                break;
            }
        }
        // Find y for max2 in AC2
        for (i = 0; i < lengthOf(xAC2); i++) {
            if (xAC2[i] == max2) {
                y2 = yAC2[i];
                break;
            }
        }
        // Draw line from (min1, y1) to (max2, y2)
        makeLine(min1, y1, max2, y2);
        roiManager("Add");  // Add line to ROI Manager
        roiManager("select", roiManager("count") - 1);
        roiManager("Rename", "Theoretical AC Boundary");

    }
    
	// === Step 1: Get diagonal line coordinates ; works for a left side but not for a right side ===
	roiManager("select", roiManager("count") - 1) ;
	getSelectionCoordinates(xLine, yLine) ;

	Array.print(xLine);
	Array.print(yLine);

	// Line points
	x1 = xLine[0];
	y1 = yLine[0];
	x2 = xLine[1];
	y2 = yLine[1];
	
	print("x1 = " + x1);
	print("y1 = " + y1);
	print("x2 = " + x2);
	print("y2 = " + y2);


	imgWidth = getWidth();
	imgHeight = getHeight();

	// === Step 2: Fit line through original points ===
	dx = x2 - x1;
	dy = y2 - y1;

    m = dy / dx;
    b = y1 - m * x1;

    // Intersections with image bounds
    // Left edge (x = 0)
    xA = 0;
    yA = m * xA + b;

    // Right edge (x = imgWidth)
    xB = imgWidth;
    yB = m * xB + b;

    // Top edge (y = 0)
    yC = 0;
    xC = (yC - b) / m;

    // Bottom edge (y = imgHeight)
    yD = imgHeight;
    xD = (yD - b) / m;
    
    pointsX = newArray(0);
	pointsY = newArray(0);

    Array.print(pointsX);
    Array.print(pointsY);

    if (yA >= 0 && yA <= imgHeight) {
    tempX = newArray(1); tempX[0] = xA;
    tempY = newArray(1); tempY[0] = yA;
    pointsX = Array.concat(pointsX, tempX);
    pointsY = Array.concat(pointsY, tempY);
	}
	if (yB >= 0 && yB <= imgHeight) {
    tempX = newArray(1); tempX[0] = xB;
    tempY = newArray(1); tempY[0] = yB;
    pointsX = Array.concat(pointsX, tempX);
    pointsY = Array.concat(pointsY, tempY);
	}
	if (xC >= 0 && xC <= imgWidth) {
    tempX = newArray(1); tempX[0] = xC;
    tempY = newArray(1); tempY[0] = yC;
    pointsX = Array.concat(pointsX, tempX);
    pointsY = Array.concat(pointsY, tempY);
	}
	if (xD >= 0 && xD <= imgWidth) {
    tempX = newArray(1); tempX[0] = xD;
    tempY = newArray(1); tempY[0] = yD;
    pointsX = Array.concat(pointsX, tempX);
    pointsY = Array.concat(pointsY, tempY);
	}


    // Pick the two farthest-apart points (to define full-length line)
    if (lengthOf(pointsX) == 2) {
        x1 = pointsX[0];
        y1 = pointsY[0];
        x2 = pointsX[1];
        y2 = pointsY[1];
    } else {
        showMessage("Error", "Line does not intersect two edges cleanly.");
        exit();
    }

	print("x1 =" + x1);
	print("y1 =" + y1);
	print("x2 =" + x2);
	print("y2 =" + y2);
	
	// Draw line from (x1, y1) to (x2, y2)
    makeLine(x1, y1, x2, y2);
    roiManager("Add");  // Add line to ROI Manager
    roiManager("select", roiManager("count") - 1);
    roiManager("Rename", "Extended AC Boundary");



if (Hemisphere == "Left") { 

	// === Step 2: Create upper and lower polygon masks based on the line, for left hemispheres ===
	if (y2 == 0) {
    // Upper mask (just the triangle between 0,0 and the line)
    makePolygon(
        0, 0,
        x2, y2,
        x1, y1
    );
    run("Create Mask");
    rename("upper_mask");
    
    // Lower mask (everything below the triangle)
    makePolygon(
        x1, y1,
        x2, y2,
        imgWidth, 0,
        imgWidth, imgHeight,
        0, imgHeight
    );
    run("Create Mask");
    rename("lower_mask");
    
	} else {
    // Upper mask (everything above the line)
    makePolygon(
        0, 0,
        imgWidth, 0,
        x2, y2,
        x1, y1
    );
    run("Create Mask");
    rename("upper_mask");

    // Lower mask (everything below the line)
    makePolygon(
        x1, y1,
        x2, y2,
        imgWidth, imgHeight,
        0, imgHeight
    );
    run("Create Mask");
    rename("lower_mask");
}
}

if (Hemisphere == "Right") { 

	// === Step 2: Create upper and lower polygon masks based on the line, for right hemispheres ===
	if (y2 == 0) {
    // Upper mask (just the triangle between 0,0 and the line)
    makePolygon(
        x2, y2,
        x1, y1,
        imgWidth, 0
    );
    run("Create Mask");
    rename("upper_mask");
    
    // Lower mask (everything below the triangle)
    makePolygon(
        x1, y1,
        imgWidth, imgHeight,
        0, imgHeight,
        0, 0,
        x2, y2
    );
    run("Create Mask");
    rename("lower_mask");
    
	} else {
    // Upper mask (everything above the line)
    makePolygon(
        0, 0,
        imgWidth, 0,
        x1, y1,
        x2, y2
        
    );
    run("Create Mask");
    rename("upper_mask");

    // Lower mask (everything below the line)
    makePolygon(
        x2, y2,
        x1, y1,
        imgWidth, imgHeight,
        0, imgHeight
    );
    run("Create Mask");
    rename("lower_mask");
}
}


// === Step 3: Find and mask the pallidum ROI ===
	pallidumIndex = -1;
for (i = 0; i < roiManager("count"); i++) {
    name = RoiManager.getName(i);
    if (indexOf(name, "16711798") != -1) {
        pallidumIndex = i;
        break;
    }
}

if (pallidumIndex == -1) {
    showMessage("Error", "ROI with ID 16711798 not found.");
    exit();
}

	// Create binary mask from pallidum ROI
	roiManager("select", pallidumIndex);
	run("Create Mask");
	rename("pallidum_mask");

	// === Step 4: Duplicate pallidum mask and AND with upper/lower masks ===
	selectWindow("pallidum_mask");
	run("Duplicate...", "title=pallidum_upper");
	run("Duplicate...", "title=pallidum_lower");

	selectWindow("pallidum_upper");
	imageCalculator("AND create", "pallidum_upper", "upper_mask");

	selectWindow("pallidum_lower");
	imageCalculator("AND create", "pallidum_lower", "lower_mask");

	// === Step 5: Convert to ROIs and name them ===

	selectWindow("Result of pallidum_lower");
	run("Create Selection");
	roiManager("Add");
	roiManager("select", roiManager("count") - 1);
	roiManager("Rename", "0001 - ID 16711799");

	selectWindow("Result of pallidum_upper");
	run("Create Selection");
	roiManager("Add");
	roiManager("select", roiManager("count") - 1);
	roiManager("Rename", "0001 - ID 16711800");


for (i = 0; i < roiManager("count"); i++) {
    name = RoiManager.getName(i);
    
     if (name == "0001 - ID 16711799") {
        found = true;
    }
}

// If found, then delete ROI with name that ends in "16711798"
if (found) {
    for (i = 0; i < roiManager("count"); i++) {
        name = RoiManager.getName(i);
        if (endsWith(name, "16711798")) {
            roiManager("select", i);
            roiManager("delete");
            break;
        }
    }
	}
	// === Cleanup ===
	close("pallidum_mask");
	close("upper_mask");
	close("lower_mask");
	close("pallidum_upper");
	close("pallidum_lower");
	close("Result of pallidum_upper");
	close("Result of pallidum_lower");
	} else {
    print("Found 1 Anterior Commisure Section. Continuing...");
}


// Part 2                                  //
// Create an array of all unique ROI names //
//                                         //
	
	
	// Reset arrays so we don't reuse outdated values
	roiNumbers = newArray();
	uniqueNumbers = newArray();

	// Re-scan the ROI Manager for updated ROI list
	n = roiManager("count");
	roiNumbers = newArray(n);

	// Extract ID numbers again from the new ROI list
for (i = 0; i < n; i++) {
    name = RoiManager.getName(i);

    // Skip AC reference lines — they should NOT be grouped
    if (name == "Theoretical AC Boundary" || name == "Extended AC Boundary") {
        roiNumbers[i] = "SKIP";
        continue;
    }

    parts = split(name, " - ID ");
    if (parts.length > 1) {
        roiNumbers[i] = parts[1];   // Extract numeric ID
    } else {
        roiNumbers[i] = "Unknown";
    }
}

	// Sanity check - print all ROI numbers
	Array.print(roiNumbers);	
	

	// Iterate through roiNumbers to find unique values
for (i = 0; i < lengthOf(roiNumbers); i++) {
    number = roiNumbers[i];
    
    // Check if the number is already in uniqueNumbers
    isUnique = true;
	for (j = 0; j < lengthOf(uniqueNumbers); j++) {
        if (uniqueNumbers[j] == number) {
            isUnique = false;
            break;
        }
	}
    
    // If it's unique, add it to the array
    if (isUnique) {
        uniqueNumbers[lengthOf(uniqueNumbers)] = number;
    }
}

	// Sanity check - print all unique numbers
	Array.print(uniqueNumbers);

		 
// Part 3                                               //
// Find indices of all unique ROI names within ROI list //
//                                                      //


	// Initialize an empty array to store indices for each unique number
	positions = newArray(lengthOf(uniqueNumbers));

	// Loop through each unique number 
for (i = 0; i < lengthOf(uniqueNumbers); i++) {
    currentNumber = uniqueNumbers[i];
    indices = ""; // Use a string to store indices
    
    // Loop through roiNumbers to find matching positions
    for (j = 0; j < lengthOf(roiNumbers); j++) {
        if (roiNumbers[j] == currentNumber) {
            if (indices == "") {
                indices = "" + j; // First index (avoid leading comma)
            } else {
                indices += "," + j; // Append subsequent indices
            }
        }
    }
    // Store the indices string in the positions array
    positions[i] = indices;
}

	// Sanity check - print all ROI positions of each unique number
	Array.print(positions);


// Part 4                                                             //
// Combine ROIs based on unique identifiers, and add them to ROI list //    
//                                                                    //

	// Ensure the ROI Manager is open
	if (roiManager("count") == 0) {
    exit("No ROIs found in ROI Manager!");
	}

	// Loop through each unique number to find the positions of this number within the ROI manager
for (i = 0; i < lengthOf(uniqueNumbers); i++) {
    print(uniqueNumbers[i] + "'s corresponding positions: " + positions[i]);
     
    // Extract ROI manager indices for this unique number
    indices = split(positions[i], ",");
    
    // Convert ROI manager indices to an integer array
    indexArray = newArray(lengthOf(indices));
    for (j = 0; j < lengthOf(indices); j++) {
        indexArray[j] = parseInt(indices[j]);
    }
    
    // Sanity check - print integer array of these ROI manager positions 
    Array.print(indexArray);
    
    // Deselect all before selecting new ones
    roiManager("deselect");

    // Select all ROIs at once
    roiManager("select", indexArray);
        
    roiManager("combine"); // Combine the selected ROIs
    roiManager("Add"); // Adds the combined ROI to the ROI Manager
	roiManager("Select", roiManager("Count")-1); // Selects the combined ROI
	roiManager("Rename", uniqueNumbers[i] + "_COMBINED"); // Rename the combined ROI as "[the Unique number]_COMBINED"
}


// Part 5                                                                       //
// Delete all non-combined ROIs, except AC boundaries, and remove SKIP_COMBINED // 
//                                                                              //
	n = roiManager("count");

	// Loop backwards while deleting
for (i = n - 1; i >= 0; i--) {
    roiName = RoiManager.getName(i);
    keepAC = (roiName == "Theoretical AC Boundary") || (roiName == "Extended AC Boundary");
    isCombined = endsWith(roiName, "_COMBINED");

	// Special case: SKIP_COMBINED should be deleted ALWAYS
    if (roiName == "SKIP_COMBINED") {
        print("Deleting SKIP_COMBINED explicitly");
        roiManager("select", i);
        roiManager("delete");
        continue;
    }

    // Delete anything that:
    //  - is NOT combined AND
    //  - is NOT one of the AC boundary ROIs
    if (!isCombined && !keepAC) {
        print("Deleting ROI: " + roiName);
        roiManager("select", i);
        roiManager("delete");
    }
}


// Part 6                                  //
// Rename each ROI with a predefined atlas //  
//                                         //

	// Define the mapping of ROI names to new names
	roiKey = newArray(
	"9251276_COMBINED", "Ventricle",
	"2739291_COMBINED", "Cortex",
    "20223_COMBINED", "Striatum",
    "65358_COMBINED", "Septum",
    "2710476_COMBINED", "BNST",
    "13418281_COMBINED", "Corpus Callosum",
    "2729676_COMBINED", "Olfactory Structures",
    "10354432_COMBINED", "Anterior Commissure",
    "13379881_COMBINED", "Accumbens",
    "9292841_COMBINED", "IPAC/Extended Amygdala",
    "4377641_COMBINED", "Preoptic Area",
    "50431_COMBINED", "Hypothalamus",
    "16711798_COMBINED", "Ventral Pallidum",
    "65476_COMBINED", "Diagonal Domain",
    "13380031_COMBINED", "Optic Tract",
    "13399081_COMBINED", "Fornix",
    "10289407_COMBINED", "Internal Capsule",
    "16711799_COMBINED", "Ventral Pallidum",
    "16711800_COMBINED", "Globus Pallidus"
	);
	

	// Build a unique list of region names from roiKey
	regionNames = newArray();
	
for (i = 1; i < lengthOf(roiKey); i += 2) {
    name = roiKey[i];
    isUnique = true;
    
    // Check if already added
    for (j = 0; j < lengthOf(regionNames); j++) {
        if (regionNames[j] == name) {
            isUnique = false;
            break;
        }
    }
    
    if (isUnique) {
        regionNames[lengthOf(regionNames)] = name;
    }
}


	// Get the total number of ROIs
	n = roiManager("count");

	// Loop through ROIs and rename them based on the key
for (i = 0; i < n; i++) {
	roiName = RoiManager.getName(i);
	roiManager("select",i);
    
    // Find matching name in the key
    for (j = 0; j < lengthOf(roiKey); j += 2) {
        if (roiName == roiKey[j]) {
            newName = roiKey[j + 1];            
            roiManager("rename", newName);
            print("Renamed " + roiName + " to " + newName);
            break; // Stop checking once found
        }
    }
}


	selectImage(baseName);
		
	// Extract ID (by finding all characters before the first underscore - works at least for KEK 75-108)
	underscorePos = indexOf(baseName, "_");
if (underscorePos != -1) {
    Rat_ID = substring(baseName, 0, underscorePos);
    print("Rat ID: " + Rat_ID);
	} else {
    print("No Rat ID found.");
}

	
	// Extract Approximate A/P position based on name (by finding all characters after the first underscore and before "VP")
	VPPos = indexOf(baseName, "VP");
if (underscorePos != -1 && VPPos != -1 && VPPos > underscorePos) {
 	Approximate_AP = substring(baseName, underscorePos + 1, VPPos);
    print("Approximate A/P position: " + Approximate_AP);
	} else {
    print("No approximate A/P position specified.");
}
	
	// Extract hemisphere (should work for pretty much all the images)	
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
	
	nRois = roiManager("count");	
		
	// Create or open the Results Table
	rt = Table.create("Results");
	// Add results in a **single row**
	rowIndex = Table.size;
	Table.set("File Name", rowIndex, baseName);
	Table.set("Rat ID", rowIndex, Rat_ID);
	Table.set("Approximate AP Section", rowIndex, Approximate_AP);
	Table.set("Hemisphere", rowIndex, Hemisphere);
	Table.set("Total Cells", rowIndex, 0);
	
	// Add static table columns for each atlas region (unique only)
for (i = 0; i < lengthOf(regionNames); i++) {
    Table.set(regionNames[i], rowIndex, 0);
}
	
	// Open multi-point ROIs previously set at each cell position (along with a hand-drawn VP used for previous allocation)
	dirPath = "\\EnterROIPathHere\\" + baseName + " - ROIs.zip";
	roiManager("Open", dirPath);
	
	nRois = roiManager("count");
		
	// Rename "VP boundary" to clarify it was the one hand-drawn before
	roiManager("select", nRois - 2);
    roiManager("Rename", "VP boundary - hand-drawn previously");

	
	Multipointidx = nRois-1;
	
	// Find all (x,y) coordinates for each previously selected cell
	roiManager("select", nRois - 1);
	getSelectionCoordinates(xpoints, ypoints);
	total_cells = xpoints.length;	
	
// Determine correct starting index
firstName = RoiManager.getName(0);
if (firstName == "Theoretical AC Boundary") {
    startIndex = 2;
} else {
    startIndex = 0;
}

// iterate through total cells once and distinguish which region it belongs in
for (i = startIndex; i < nRois - 2; i++) {
    roiName = RoiManager.getName(i);
    roiManager("select", i);
    Regionidx = i;
        
    roiManager("select", Multipointidx);
    getSelectionCoordinates(xpoints, ypoints);

    total_cells = xpoints.length;  // Count all points
	inside_cells = 0;
	
	// Select the current brain region ROI
    roiManager("select", Regionidx);
	 
   for (j = 0; j < xpoints.length; j++) {
   if (selectionContains(xpoints[j], ypoints[j])) {
   inside_cells++;
   } 
   }
   
    print("Total points overall: " + total_cells);
	print("Total points inside " + roiName + ": " + inside_cells);
	
    Table.set("Total Cells", rowIndex, total_cells);
	Table.set(roiName, rowIndex, inside_cells);
    	      
}
    	
	Table.update();
	
	
	// Save aligned brain regions, along with the cell selections and the old hand-drawn VP boundary. 
	ROIPath = "\\EnterROIPathHere\\";
	roiManager("Deselect");
	roiManager("Save", ROIPath + "/" + baseName + "_FinalAlignedROIs.zip");	
	
	// Write and save results to an excel file.
	run("Read and Write Excel", "no_count_column file=\\EnterROIPathHere\\ExcelName.xlsx stack_results dataset_label=" + baseName); 
		
	// clear everything so it doesn't mess up your next run through
	roiManager("Deselect");
	roiManager("Reset");			 // Clear the ROI Manager 
	run("Close All");                // Close all open images
	run("Clear Results");            // Close the Results panel
	
	print("Finished! Atlas Alignment Results saved.");
	
	
	