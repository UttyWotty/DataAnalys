# DataAnalysis
Analyzing Data for work practise using medicine dataset. Steps i took as follow; 

- Predicting Review Percentages with Machine Learning
This project involves predicting review percentages of medicines using a machine learning model, specifically the Random Forest Regressor. It includes data preprocessing, exploratory data analysis (EDA), and machine learning steps, followed by model evaluation and visualization of the results.

  Step 1: Data Preprocessing
In this step, I prepare the data for the machine learning model by cleaning and transforming it.

  1.1 Check for Duplicates and Missing Values
Before starting with the analysis, I ensure the dataset is clean by:

Removing duplicate entries: Duplicates can distort the analysis and model performance.
Handling missing values: We either fill or drop rows with missing data to ensure the model gets accurate inputs.

  1.2 Convert Categorical Data to Numeric for Machine Learning
Machine learning algorithms, like Random Forest, require numerical data to function. Since this dataset contains some categorical (text) data (like "Composition" and "Manufacturer"), I use a technique called label encoding to convert these text columns into numbers:

Label Encoding: This method assigns a unique number to each category. For example, "Manufacturer A" might be encoded as 0, "Manufacturer B" as 1, and so on.
By converting categorical columns to numbers and  make the data ready for machine learning models.

  Step 2: Exploratory Data Analysis (EDA)
Exploratory Data Analysis (EDA) is a way to understand the data before building the machine learning model.

  2.1 Distribution of Review Percentages
In this step, I analyze the distribution of the three types of reviews: Excellent, Average, and Poor reviews. I also use visualizations, such as histograms, to see how the reviews are spread out across the dataset.

Purpose: This helps us understand the overall review pattern and whether there are any skewed or imbalanced distributions.

  2.2 Interactive Bar Plot for Manufacturers
I create an interactive bar plot to explore how many products each manufacturer has. This helps us understand the diversity of manufacturers in the dataset and whether the number of products from each manufacturer is balanced.

  2.3 3D Scatter Plot: Reviews vs. Composition
This 3D scatter plot compares the three types of reviews (Excellent, Average, and Poor) against the composition of the medicines. Each point represents a medicine, with its composition (categorical data converted to numeric) and review percentages plotted in three dimensions.

  Purpose: This visualization helps us see the relationship between the composition of the medicine and its reviews.
  
  2.4 Word Cloud for "Uses" and "Side Effects"
A word cloud is created to visualize the most common words in the "Uses" and "Side Effects" columns. This gives a quick overview of what each medicine is commonly used for and its most frequently reported side effects.

Purpose: Helps identify the most important terms and patterns within the textual data.

  Step 3: Machine Learning
The machine learning phase involves training a model to predict review percentages based on the other features in the data.

  3.1 Predicting Review Percentages with Random Forest
  
I use a Random Forest Regressor to predict the review percentages. A Random Forest is an ensemble of decision trees, which means it combines multiple decision trees to improve the accuracy of the predictions.

Training the Model: The model is trained using historical data to understand how the features (such as composition, uses, side effects, etc.) relate to the review percentages.
Target Variable: The target variable we aim to predict is the Excellent Review % (i.e., how likely a product is to receive an excellent review).

  3.2 Feature Importance
Once the model is trained, we can evaluate which features (columns in the dataset) are the most important in predicting the review percentages. This is done by calculating feature importance, which shows how much each feature contributes to the model's prediction.

Purpose: This step helps us understand what factors most influence review percentages, such as composition or side effects.

  3.3 Model Evaluation with Cross-Validation
I evaluate the model’s performance by splitting the data into training and testing sets, training on one set, and testing on another. We also use cross-validation, which means splitting the data multiple times to check the model’s accuracy.

Mean Squared Error (MSE): This metric helps us assess the model’s performance by comparing the predicted values against the actual values. The smaller the MSE, the better the model is at making predictions.

  Step 4: Model Tuning and Enhancement
After training the initial model, we can try improving its performance.

In this step, we may adjust parameters, such as the number of decision trees in the Random Forest or the depth of each tree. These adjustments are done to increase the model’s accuracy and generalization ability.

Purpose: This process ensures the model performs well on new, unseen data and avoids overfitting (i.e., when the model performs well on training data but poorly on test data).
  Step 5: Interactive Visualization of Predictions
The final step involves creating interactive visualizations to explore the model's predictions and their accuracy.

Purpose: This step helps stakeholders interact with the model and predictions, allowing them to explore different review percentages predicted by the model for various medicines.
Interactive plots or dashboards make it easier to understand how the model works and which factors lead to certain review percentages.

Conclusion
By following these steps, we've built a machine learning model that predicts review percentages based on different features of medicines. The model was trained, evaluated, and fine-tuned to ensure its accuracy. This process involved:

* Preprocessing the data (cleaning and encoding categorical values)
* Exploring the data visually and interactively
* Building and training the model using Random Forest
* Evaluating the model's performance
* Tuning the model for better predictions
This project provides a comprehensive approach to predicting review percentages, and the results can be applied to improve decision-making in the medicine industry.


