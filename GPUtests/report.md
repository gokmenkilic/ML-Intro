# AI/ML Update Report: Migration of ML Course Dataset Source

## 1. Problem Statement
The machine learning course notebooks originally relied on **Google Cloud Storage (GCS)** to host dataset files (approx. 14 GB). Access was handled via the `gcsfuse` tool, which "mounted" the cloud bucket as a local drive. 

This pipeline failed when the billing account associated with the Google Project (`sciml-workshop`) was disabled, rendering the original bucket inaccessible and causing `403 Forbidden` errors for all users and automated scripts.

## 2. Solution Overview
To ensure permanent, cost-free, and high-speed access for all users, the dataset storage strategy was migrated from the external cloud to an **internal COSMA web server**.

| Feature | Old Architecture | New Architecture |
| :--- | :--- | :--- |
| **Host** | Google Cloud Platform | Durham COSMA (VirgoDB) |
| **Protocol** | FUSE Mount (`gcsfuse`) | HTTP Direct Download |
| **Auth** | GCloud Authentication | Public (Read-Only) |

## 3. Dataset Implementation

### 3.1 Data Mirroring
The full dataset was recovered from the STFC Echo backup which can be found [here](https://github.com/stfc-sciml/sciml-workshop/blob/master/course_3.0/CLASSICAL/regression_decision_tree.ipynb) and mirrored to the COSMA public web directory:
* **Storage Path:** `/cosma7/data/www/publicdata/dc-kili1/sciml-workshop-data/`
* **Web Endpoint:** `https://virgodb.cosma.dur.ac.uk/public/dc-kili1/sciml-workshop-data/`

The data loading logic in the notebooks was replaced with a direct download script that caches files locally, removing the need for `s3fs` or Google authentication. This is more faster than other methods.

## 4. Code Maintenance

* **Scope:** All **23 notebooks** were reviewed.

 Domain | Number of notebooks  | 
| :------------ |:---------------:|
| Material    | 6       |    
| Astronomy   | 6       |  
| Physics     | 6       |    
| Healthcare  | 2       | 
| Fusion      | 3       |  

* **Updates:**
    * **Library Updates:** Updated dependencies to compatible versions of TensorFlow, PyTorch, and Scikit-learn.
    * **Error Resolution:** Fixed runtime errors.
    * **Warning Suppression:** Handled verbose warning logs to ensure clean output.
    * **Validation:** All notebooks were successfully executed in a GPU-enabled environment.

The updated notebooks are available in the testing branch:  
[https://github.com/gokmenkilic/ML-Intro/tree/gk/tests/GPUtests](https://github.com/gokmenkilic/ML-Intro/tree/gk/tests/GPUtests)

## 5. Performance Benchmark
To verify the improvements, we compared the data loading verification process between the old Google Cloud method and the new COSMA implementation for Glaxy Classification [example](https://github.com/gokmenkilic/ML-Intro/blob/gk/tests/GPUtests/Astronomy/Astronomy_Galaxy_Classification_(CNN)_solution_GPU.ipynb). 

- Run on CPU: all 50 epochs results in 1,649 seconds ~28min
- Run on GPU(T4): 59 seconds.

Here is compared benchmark results:

| Metric | CPU (Previous Run) | T4 GPU (Current Run) | Speedup Factor |
| :--- | :--- | :--- | :--- |
| **Time per Epoch** | ~33 seconds | ~1 second | **33x Faster** |
| **Step Time** | ~140ms / step | ~6ms / step | **23x Faster** |
| **Total Training Time** | ~27 min 30 sec | ~1 minute | **~27x Faster** |

## 6. Next Steps

- Try to migrate  notebooks on [AziMuth](https://portal.azimuth.cosma.dur.ac.uk), may gain more flexiblty and GPU(A100).
- Tiding up the notebooks with the sub-folders. For example, two notebook under the healthcare is originally the subjects of Astrochemistry with show case paper. However, they located under the healtcare folder.
