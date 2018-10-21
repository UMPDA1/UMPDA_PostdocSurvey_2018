# https://rpubs.com/joshyazman/sentiment-analysis-lexicon-comparison
# https://www.tidytextmining.com/
# https://lizrush.gitbooks.io/algorithms-for-webdevs-ebook/content/
# https://www.kaggle.com/xvivancos/analyzing-star-wars-movie-scripts
# https://www.kaggle.com/cosinektheta/mining-the-women-s-clothing-reviews
# https://www.kaggle.com/ambarish/seinfeld-text-mining-wordembeddings-modelling
# https://www.kaggle.com/ambarish/fun-in-text-mining-with-simpsons


# sentiment scores (several options)
  # do by question and include most pos/neg words
  # look at emotions (fear, joy, etc.)
  # sentiment of question + sentiment of words in each questions
# word importance (LDA/TF-IDF)
# word clouds (can do in shape of something)
# word relationships
  # networks
  # bigrams
  # trigrams


# plan:
  # break responses into individual words (tokenization)
  # remove common words to focus analysis
  # pool all responses and analyze each question
  # break responses up by strat ids and analyze each question

# list of questions with text responses
  # Q: 

# when comparing all the data
# word cloud per question
  # tokens vs bigrams vs trigrams
# top 20 tokens per question chart
# top 20 bigrams
# top 20 trigrams

# when comparing stratifications
# everything from before but add:
# TF-IDF (most important words per question) - token
# TF-IDF - bigram
# TF-IDF - trigram

# importing stuff ---------------------------------------------------------

# import dataset
source("code/stratify_data.R")


library(tidyverse)
library(tidytext) # text manipulation, used for tokenization and stop words
# library(wordcloud) # word cloud
# library(wordcloud2)
library(ggwordcloud) # geom_text_wordcloud()
# library(stringr) #string manipulation
# library(igraph)
# library(ggraph)
# 
# library(widyr)
# library(broom)
# 
# library(DT)
# 
# library(irlba)
# library(topicmodels) # for LDA topic modelling 
# library(tm) # general text mining functions, making document term matrixes
# 
# library(caret)
# library(glmnet)



# text analysis -----------------------------------------------------------

# NOTE: stop_words includes "no", "not", etc. which may be bad for some types of analyses

# creating list of all the questions
question_list <- unique(tidy_survey_data$question_no)

# making list of questions to exclude from graph generation because they were typed response
# to change the questions included in this list, add/subtract/change the numbers in paste0() as desired
typed_question_list <- question_list[grepl(paste(paste0("Q", c(23,29,42,43,44,45,46,51)), collapse = "|"), question_list)]

typed_question_df <- tidy_survey_data %>%
  filter(question_no %in% typed_question_list) %>%
  mutate(response = str_replace_all(response, "_", " ")) %>%
  filter(!is.na(response) & !str_detect(response, "\\bn[/]a\\b"))
# 
# 
# typed_question_df %>% 
#   filter(question_no == "Q51" & !is.na(response)) %>%
#   createWordCloud()

# setting the seed for all functions in script (could put in original tidy script to have propagate through all scripts)
my_seed <- 2018

# tf-idf ------------------------------------------------------------------

# NOTE: Because of the size of the dataset at present (2018), tf-idf is limited because there aren't enough repeats of n-grams
# so several n-grams all have the same tf-idf value which makes plotting difficult. Could be fixed by repeating the survey and
# expanding the available data but limits yearly evaluations

# Term Frequency - Inverse Document Frequency (aka most important words)
# need to compare questions that are inverse of each other
# works similar to random forest modelling by finding words that are common but to only a subset of the collection of documents



# creating function to break responses into n-grams
# survery_df = df containing survey responses; n_token = size of n-gram to use (ex: 2 = bigram)
get_n_gram <- function(survey_df, n_token) {
  
  # converting data to form for parsing
  data <- survey_df %>%
    mutate(response = str_replace_all(response, "_", " ")) # reformatting responses to remove any "_" from tidying process
  
  # creating list of unigrams
  if (n_token == 1) {
    
    n_gram_df <- data %>% 
      unnest_tokens(n_gram, response) %>% # breaking responses up into individual words
      filter(!n_gram %in% stop_words$word) # filtering out stop words from tokens
    
  # creating list of bigrams
  } else if (n_token == 2) {
    
    n_gram_df <- data %>% 
      unnest_tokens(n_gram, response, token = "ngrams", n = 2) %>% # breaking data up into bigrams
      separate(n_gram, c("word1", "word2"), sep = " ") %>% # separating bigrams into individual cols to filter out stop words
      filter(!word1 %in% stop_words$word) %>% # removing stop words from col1
      filter(!word2 %in% stop_words$word) %>% # removing stop words from col2
      unite(n_gram, word1, word2, sep = " ") # reuniting words to reform bigrams
  
  # creating list of trigrams
  } else if (n_token == 3) {
    
    n_gram_df <- data %>% 
      unnest_tokens(n_gram, response, token = "ngrams", n = 3) %>% # breaking data up into bigrams
      separate(n_gram, c("word1", "word2", "word3"), sep = " ") %>% # separating bigrams into individual cols
      filter(!word1 %in% stop_words$word) %>% # removing stop words from col1
      filter(!word2 %in% stop_words$word) %>% # removing stop words from col2
      filter(!word3 %in% stop_words$word) %>% # removing stop words from col3
      unite(n_gram, word1, word2, word3, sep = " ") # reuniting words to reform bigrams
    
  # making message for debugging
  } else {
    
    print("ERROR: n_token value invalid. Must be 1, 2, or 3.")
    
  }
  
  # outputting n-gram list
  return(n_gram_df)
  
}


# NOTE: can combine calc functions

# creating function to calculate term frequency for entire dataset
calc_tf <- function(survey_df, n_token, question_no_chr) {
  
  # generating term frequency df
  tf_df <- survey_df %>% 
    filter(question_no == question_no_chr) %>% # filtering based on desired question
    get_n_gram(n_token) %>% # generating list of n-grams
    count(n_gram, sort = TRUE) %>% # counting occurrences of each n-gram
    mutate(tf = n/sum(n)) %>% # calculating term frequencies based on total number of n-grams in dataset
    arrange(desc(tf)) #%>% # ordering output based on tf value
    #mutate(question = tidy_survey_data %>% filter(question_no == question_no_chr) %>% pull(question) %>% unique()) # adds col with question text back in
  
  # returning the output
  return(tf_df)
  
}



# creating function to calculate tf-idf for stratified data
calc_tf_idf <- function(survey_df, n_token, question_no_chr) {
  
  # creating df of tf-idf values for each n-gram
  tf_idf_df <- survey_df %>% 
    filter(question_no == question_no_chr) %>% # filtering based on desired question
    get_n_gram(n_token) %>% # running user function to generate list of n-grams
    count(strat_id, n_gram, sort = TRUE) %>% # counting instances of each n-gram in each strat_id
    bind_tf_idf(n_gram, strat_id, n) %>% # calculating tf-idf for each n-gram
    arrange(desc(tf_idf)) # ordering output based on tf-idf value

  # returning output tf-idf values
  return(tf_idf_df)
  
}



# creating function for plotting wordclouds of specific questions based on term frequency
plot_wordcloud_tf <- function(survey_df, n_token, question_no_chr) {
  
  # creating df of term frequencies with question text attached
  tf_df <- calc_tf(survey_df, n_token, question_no_chr) %>% # calcs term frequencies for n-grams
    mutate(question = tidy_survey_data %>% filter(question_no == question_no_chr) %>% pull(question) %>% unique()) # adds col with question text back in
  
  # making df of top n-grams for each dataset
  tf_top <- tf_df %>% 
    top_n(20, tf) %>% # pulls out top 20 entries based on tf
    filter(tf != min(tf)) %>% # removing n-grams that have the smallest tf value for each group (prevents over-plotting)
    filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token/part of an n-gram (focuses data)
    mutate(n_gram = reorder(n_gram, tf)) # ordering the data to be based on value for nicer looking plots
  
  # creating the wordcloud
  tf_wordcloud <- tf_top %>%
    ggplot(aes(label = n_gram, size = tf)) + # specifying data to be plotted
    geom_text_wordcloud(color = "black", # changing color of n-grams in plot
                        eccentricity = 1, # roundness of the wordcloud
                        grid_size = 4, grid_margin = 4, # spacing between terms in cloud
                        fontface = "bold", family = "Times New Roman") + # altering font characteristics (does not inherit changes from theme())
    scale_size(range = c(4, 10)) + # setting the lower and upper bounds of text point sizes
    labs(title = str_replace_all(unique(tf_top$question), "_", " ")) + # adding the question text as the plot title
    theme_minimal() + # getting rid of all theme background
    theme(plot.title = element_text(hjust = 0.5, size = 10)) # centers the plot title and alters font size
  
  # outputting results
  return(tf_wordcloud)
  
}



# creating function to plot all of the unstratified dataset using pmap
plot_all_wordcloud_tf <- function(survey_df, n_token, question_no_chr_list) {
  
  # creating df of arguments for use with pmap
  arguments <- data_frame(survey_df = list(survey_df),
                          n_token = n_token,
                          question_no_chr = question_no_chr_list)
  
  # mapping over list of arguments in arguments df
  plots <- pmap(arguments, plot_wordcloud_tf) %>% 
    set_names(question_no_chr_list)
  
  # outputting results
  return(plots)
  
}



# # testing plot_all_wordcloud_tf()
# plot_all_wordcloud_tf(example_data, 2, typed_question_list)




# tf_idf_top <- calc_tf_idf(example_data, 2, "Q44") %>%
#   filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token/part of an n-gram (focuses data)
#   group_by(strat_id) %>% # grouping for calculations
#   top_n(30, tf_idf)
# 
# tf_idf_top_max <- tf_idf_top %>% 
#   filter(tf_idf != min(tf_idf)) # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
# 
# tf_idf_top_min <- tf_idf_top %>% 
#   filter(tf_idf == min(tf_idf)) # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
# 
# strat_val <- tf_idf_top_max %>% 
#   summarize(n_strat = n()) %>% 
#   rename(strat_id_chr = strat_id)

# # using pmap to iterate over example output
# pmap_df(df = tf_idf_top_min, strat_val, retrieve_rows) %>% 
#   print(n = 83) # printing all the rows for visualization

# tf_idf_top_max %>% 
#   bind_rows(pmap_df(df = tf_idf_top_min, strat_val, retrieve_rows))

strats <- example_data %>% pull(strat_id) %>% unique

unique(example_data$strat_id)

strats <- "UMMS"

# test %>% 
#   ifelse(!("ENG" %in% strat_id_chr), add_row(strat_id_chr = "ENG", n_strat = 0), NULL)
# 
# !(strats %in% test$strat_id_chr)
# 
# test %>% 
#   add_row(strat_id_chr = strats[!(strats %in% test$strat_id_chr)], n_strat = 0)
# 
# test2 <- test %>% 
#   add_row(strat_id_chr = strats[!(strats %in% test$strat_id_chr)], n_strat = 0)
# 
# test2 %>% 
#   bind_rows(strat_id_chr = strats[!(strats %in% test2$strat_id_chr)], n_strat = 0)

if (length(test$strat_id_chr) < length(unique(example_data$strat_id))) {
  test %>% 
    add_row(strat_id_chr = unique(example_data$strat_id)[!(unique(example_data$strat_id) %in% test$strat_id_chr)], n_strat = 0)
} else {
  test
}
  
  
#   ifelse(length(test2$strat_id_chr)  length(strats), data_frame(strat_id_chr = strats[!(strats %in% test2$strat_id_chr)], n_strat = 0), data_frame(test2))
# 
# data_frame(strat_id_chr = strats[!(strats %in% test2$strat_id_chr)], n_strat = 0)

# creating function to randomly subsample n number of rows from each strat_id group
# used to build top_n df up to a desired row number when overplotting is an issue due to multiple rows having same term freq value
retrieve_rows  <- function(df, strat_id_chr, n_top, n_strat) {
  set.seed(my_seed)
  data <- df %>% 
    filter(strat_id == strat_id_chr) %>% 
    sample_n(size = n_top - n_strat, replace = FALSE)
  return(data)
}

# creating function for plotting wordclouds of specific questions based on term frequency
plot_wordcloud_tf_idf <- function(survey_df, n_token, question_no_chr, n_top) {
  
  # creating df of term frequencies with question text attached
  tf_idf_df <- calc_tf_idf(survey_df, n_token, question_no_chr) %>% # calcs term frequencies for n-grams
    mutate(question = tidy_survey_data %>% filter(question_no == question_no_chr) %>% pull(question) %>% unique()) # adds col with question text back in
  
  # making df of top n-grams for each dataset
  tf_idf_top <- tf_idf_df %>%
    filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token/part of an n-gram (focuses data)
    group_by(strat_id) %>% # grouping for calculations
    top_n(n_top, tf_idf) # pulls out top n number of n-grams based on freq values
  
  # subsetting top n-gram df to be only n-grams with freq != min freq to prevent overplotting
  tf_idf_top_max <- tf_idf_top %>% 
    filter(tf_idf != min(tf_idf)) # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
  
  # subsetting top n-gram df to be only n-grams with freq = min freq for subsampling and rejoining with the max df to plot desired number of n-grams
  tf_idf_top_min <- tf_idf_top %>% 
    filter(tf_idf == min(tf_idf)) # removing n-grams that have the largest tf-idf values for each group
  
  # creating count table for n-grams in each strat_id
  max_counts <- tf_idf_top_max %>% 
    summarize(n_strat = n()) %>% # counting number of n-grams per strat_id
    rename(strat_id_chr = strat_id) # renaming col for use with retrieve_rows() later
  
  # overwriting max_counts to contain any strat_ids that may be missing with values set to 0
  max_counts <- if (length(max_counts$strat_id_chr) < length(unique(survey_df$strat_id))) { # if the number of strat_ids is less in the count table than the original df
    
    max_counts %>% 
      add_row(strat_id_chr = unique(survey_df$strat_id)[!(unique(survey_df$strat_id) %in% max_counts$strat_id_chr)], n_strat = 0) # add rows for missing strat_ids with n set to 0
    
  } else { # otherwise
    
    max_counts # leave it unchanged
    
  }
  
  # subsampling tf_idf_top_min df and adding back to tf_idf_top_max df to give consistent number of n-grams per strat_id for plotting
  tf_idf_top_n_grams <- tf_idf_top_max %>% 
    bind_rows(pmap_df(df = tf_idf_top_min, n_top = n_top, .l = max_counts, .f = retrieve_rows)) %>% 
    ungroup()
    
  # creating the wordcloud
  tf_idf_wordcloud <- tf_idf_top_n_grams %>%
    ggplot(aes(label = n_gram, size = tf_idf)) + # specifying data to be plotted
    geom_text_wordcloud(color = "black", # changing color of n-grams in plot
                        eccentricity = 2, # roundness of the wordcloud
                        grid_size = 5, grid_margin = 4, # spacing between terms in cloud
                        fontface = "bold", family = "Times New Roman") + # altering font characteristics (does not inherit changes from theme())
    scale_size(range = c(4, 10)) + # setting the lower and upper bounds of text point sizes
    labs(title = str_replace_all(unique(tf_idf_top_n_grams$question), "_", " ")) + # adding the question text as the plot title
    facet_wrap(~strat_id, ncol = 2, scales = "free") + # making individual plots for each strat_id
    theme_minimal() + # getting rid of all theme background
    theme(plot.title = element_text(hjust = 0.5, size = 10)) # centers the plot title and alters font size
  
  # outputting results
  return(tf_idf_wordcloud)
  
}

plot_wordcloud_tf_idf(example_data, 3, "Q44", 10)



# # creating function for plotting wordclouds of specific questions based on term frequency
# plot_wordcloud_tf_idf <- function(survey_df, n_token, question_no_chr) {
#   
#   # creating df of term frequencies with question text attached
#   tf_idf_df <- calc_tf_idf(survey_df, n_token, question_no_chr) %>% # calcs term frequencies for n-grams
#     mutate(question = tidy_survey_data %>% filter(question_no == question_no_chr) %>% pull(question) %>% unique()) # adds col with question text back in
#   
#   # making df of top n-grams for each dataset
#   tf_idf_top <- tf_idf_df %>%
#     group_by(strat_id) %>% # grouping for calculations
#     top_n(30, tf_idf) %>% # pulls out top 20 entries based on tf-idf
#     filter(tf_idf != min(tf_idf)) %>% # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token/part of an n-gram (focuses data)
#     ungroup() %>%
#     mutate(n_gram = reorder(n_gram, tf_idf)) # ordering the data to be based on value for nicer looking plots
# 
#   # creating the wordcloud
#   tf_idf_wordcloud <- tf_idf_top %>%
#     ggplot(aes(label = n_gram, size = tf_idf)) + # specifying data to be plotted
#     geom_text_wordcloud(color = "black", # changing color of n-grams in plot
#                         eccentricity = 1, # roundness of the wordcloud
#                         grid_size = 4, grid_margin = 4, # spacing between terms in cloud
#                         fontface = "bold", family = "Times New Roman") + # altering font characteristics (does not inherit changes from theme())
#     scale_size(range = c(4, 10)) + # setting the lower and upper bounds of text point sizes
#     labs(title = str_replace_all(unique(tf_idf_top$question), "_", " ")) + # adding the question text as the plot title
#     facet_wrap(~strat_id, ncol = 2, scales = "free") + # making individual plots for each strat_id
#     theme_minimal() + # getting rid of all theme background
#     theme(plot.title = element_text(hjust = 0.5, size = 10)) # centers the plot title and alters font size
#   
#   # outputting results
#   return(tf_idf_wordcloud)
#   
# }


plot_wordcloud_tf_idf(example_data, 2, "Q44")

a


#     group_by(strat_id) %>% # grouping for calculations
#     top_n(20, tf_idf) %>% # pulls out top 20 possible entries for each strat_id based on tf-idf
#     filter(tf_idf != min(tf_idf)) %>% # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token 
#     ungroup() %>% # ungroup for plotting
#     mutate(n_gram = reorder(n_gram, tf_idf)) %>% # ordering the data to be based on value for nicer looking plots
#     ggplot(aes(n_gram, tf_idf, fill = strat_id)) + # setting the plotting conditions
#     geom_col(show.legend = FALSE) + # graph will be a bar chart without a legend
#     labs(x = NULL, y = "tf-idf") + # only need the tf-idf value label (n-grams will be other labels)
#     facet_wrap(~strat_id, ncol = 2, scales = "free") + # making individual plots for each strat_id
#     coord_flip(expand = FALSE) # turns the plot sideways


# test <- calc_tf_idf(example_data, 2, "Q43") %>%
#   group_by(strat_id) %>% # grouping for calculations
#   top_n(50, tf_idf) %>% # pulls out top 20 entries based on tf-idf
#   filter(tf_idf != min(tf_idf)) %>% # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
#   filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token/part of an n-gram (focuses data)
#   ungroup() %>%
#   mutate(n_gram = reorder(n_gram, tf_idf)) # ordering the data to be based on value for nicer looking plots



### testing things ###

# creating test dataset
example_data <- strat_data$college_school %>% 
  filter(question_no %in% typed_question_list)



### running it ###














# sentiment analysis ------------------------------------------------------

# deciding which classification system to use for sentiment analysis
# afinn has best score distribution (ex: negative scores align well with negative opinions) and better range (-5 to 5) but fewer words in lexicon (2476 words)
# bing has second best score distribution and significantly more words in lexicon (6788 words) but scores are either "pos" or "neg"
get_sentiments("bing") %>% 
  select(sentiment) %>% 
  unique()
get_sentiments("afinn") %>% 
  select(score) %>% 
  unique() %>% 
  pull() %>% 
  sort()



# testing AFINN based scoring
# basing code off of example from kaggle on text mining:
# https://www.kaggle.com/ambarish/seinfeld-text-mining-wordembeddings-modelling
top_30_sentiment <- typed_question_df %>% # calling df of typed question from survey data
  mutate(response = str_replace_all(response, "_", " ")) %>% # removing all "_" left from tidying dataset
  filter(question_no == "Q43") %>% # filtering to a specific questions
  # filter(question == "What_aspects_of_your_UM_postdoctoral_fellow_have_not_been_positive?") %>% 
  unnest_tokens(word, response) %>% # breaks apart responses into individual words
  filter(!is.na(word)) %>% # removes any blank rows
  inner_join(get_sentiments("afinn"), by = "word") %>% # adds AFINN scores to words from dataset if present in each
  group_by(word) %>% # groups based on word
  summarize(n = n(), # counts number of occurrences
            cum_score = sum(score)) %>% # calculates (score * number of occurrences) of each word to find relative contribution to total score
  mutate(percent_score = (cum_score / sum(cum_score)) * 100) %>%  # calculates percent of total score attributed to each word
  arrange(desc(percent_score)) %>% # arranges words based on percent score (makes human readable but not preserved for plotting)
  mutate(word = reorder(word, percent_score)) %>% # reorders the words for use in plotting
  top_n(30, abs(cum_score)) # selects top number of words based on absolute score for contribution

# plotting based on sentiment scores
top_30_sentiment %>% 
  ggplot(aes(word, percent_score, fill = percent_score > 0)) + # colors based on score
  geom_col(show.legend = TRUE) + # makes bar plot
  coord_flip() # turns plot on its side

# NOTE: AFINN is score based so quantitative scores can be calculated/plotted, bing is classification based so is only binary pos or neg

typed_question_df %>% 
  mutate(response = str_replace_all(response, "_", " ")) %>% 
  unnest_tokens(word, response) %>% 
  filter(!is.na(word)) %>% 
  inner_join(get_sentiments("nrc"), by = "word")



# wordclouds --------------------------------------------------------------

top_30_sentiment %>% 
  wordcloud2(word, size = 0.5)


# notes -------------------------------------------------------------------

# # cmd for removing weird NA responses if desired
# filter(str_detect(response, regex(paste(paste0("\\b", c("n[/]a", "na"), "\\b"), collapse = "|"), ignore_case = TRUE)))



# NOTE: need to change color scheme
# NOTE: combine calc function and plot function then take out question col from calc function and only have in plot

# # creating plotting function for looking at tf for each question/dataset
# plot_tf <- function(tf_df) {
#   
#   tf_data <- tf_df %>% 
#     top_n(20, tf) %>% # pulls out top 20 entries based on tf
#     filter(tf != min(tf)) %>% # removing n-grams that have the smallest tf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token 
#     mutate(n_gram = reorder(n_gram, tf)) # ordering the data to be based on value for nicer looking plots
#   
#   response_no <- length(unique(tf_data$n_gram)) # calculating the number of unique responses for aspect ratio scaling
#   
#   aspect <- 0.2*response_no/7 # scales the aspect ratio to standardize appearance of bars after setting consistent width w/ grobbing
#   
#   tf_plot <- tf_data %>% 
#     ggplot(aes(n_gram, tf)) + # setting the plotting conditions
#     geom_col(show.legend = FALSE, fill = "red", color = "black") + # graph will be a bar chart without a legend
#     labs(title = str_wrap(str_replace_all(unique(tf_data$question), "_", " "), width = 100),
#          x = NULL, y = "tf") + # only need the tf value label (n-grams will be other labels)
#     coord_flip(expand = FALSE) + # turns the plot sideways
#     theme(plot.title = element_text(size = 10, hjust = 0.5), # sets size of chart title and centers over plot
#           axis.line = element_line(size = 0.5, color = "black"), # formatting axis lines as desired
#           axis.title = element_text(size = 10), # making all chart titles a consistent size
#           axis.title.x = element_text(margin = margin(10,0,0,0)), # adding space between x axis title and axis labels
#           axis.text = element_text(size = 8),
#           plot.margin = margin(20,20,20,20), # giving plot a bit of padding on edges in case something is plotted out of bounds
#           panel.background = element_rect(fill = "white"), # making panels have white background
#           # formatting plots to have a consistent size
#           aspect.ratio = aspect) # making size of bars compared to plot consistent
#   
#   grob_table <- ggplotGrob(tf_plot) # creates a gtable of plot features
#   
#   grob_table$widths[4] <- unit(6, "cm") # sets alignment of y axis in chart area thereby aligning all plots generated with this script (moves chart to the right)
#   grob_table$widths[6] <- unit(6, "cm") # used for alignment (moves chart to the left)
# 
#   grobbed_plot <- as_ggplot(arrangeGrob(grob_table)) # recreating the plots with updated coordinates and saving as a ggplot item
#   
#   return(grobbed_plot)
#   
# }
# 
# # testing
# map(test2, plot_tf)



# # creating plotting function for looking at tf-idf of the various strat_id's
# plot_tf_idf <- function(tf_idf_df) {
#   
#   tf_idf_plot <- tf_idf_df %>% 
#     group_by(strat_id) %>% # grouping for calculations
#     top_n(20, tf_idf) %>% # pulls out top 20 possible entries for each strat_id based on tf-idf
#     filter(tf_idf != min(tf_idf)) %>% # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token 
#     ungroup() %>% # ungroup for plotting
#     mutate(n_gram = reorder(n_gram, tf_idf)) %>% # ordering the data to be based on value for nicer looking plots
#     ggplot(aes(n_gram, tf_idf, fill = strat_id)) + # setting the plotting conditions
#     geom_col(show.legend = FALSE) + # graph will be a bar chart without a legend
#     labs(x = NULL, y = "tf-idf") + # only need the tf-idf value label (n-grams will be other labels)
#     facet_wrap(~strat_id, ncol = 2, scales = "free") + # making individual plots for each strat_id
#     coord_flip(expand = FALSE) # turns the plot sideways
#   
#   return(tf_idf_plot)
#   
# }



# plot_wordcloud_tf <- function(tf_df) {
#   
#   tf_data <- tf_df %>% 
#     top_n(20, tf) %>% # pulls out top 20 entries based on tf
#     filter(tf != min(tf)) %>% # removing n-grams that have the smallest tf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token 
#     mutate(n_gram = reorder(n_gram, tf)) # ordering the data to be based on value for nicer looking plots
#   
#   tf_wordcloud <- tf_data %>%
#     ggplot(aes(label = n_gram, size = tf)) +
#     geom_text_wordcloud(eccentricity = 1, grid_size = 4, grid_margin = 3, fontface = "bold", family = "Times New Roman") +
#     scale_size(range = c(5, 15)) +
#     labs(title = "Test") +
#     theme_minimal()
#   
#   return(tf_wordcloud)
#   
# }
# 
# plot_wordcloud_tf2(test2$Q43)
# 
# map(test2, plot_wordcloud_tf2)



# calc_tf <- function(survey_df, n_token, question_no_chr) 
# setting up mapping function to loop through all plots and question numbers of stratified data
# save_all_strat_plots <- function(plot_list, question_no_chr_list, category) {
#   arguments <- data_frame(plot_name = plot_list,
#                           question_no_chr = question_no_chr_list)
#   pmap(arguments, save_strat_plots, category = category)
# }

# test_function <- function(survey_df, n_token, question_no_chr_list) {
#   arguments <- data_frame(survey_df = list(survey_df),
#                           n_token = n_token,
#                           question_no_chr = question_no_chr_list)
#   data <- pmap(arguments, calc_tf) %>% 
#     set_names(question_no_chr_list)
#   return(data)
# }
# 
# test2 <- test_function(example_data, 2, typed_question_list)
# 
# map(test2, plot_tf)

# plot_wordcloud_tf_idf <- function(tf_idf_df) {
#   
#   tf_idf_data <- tf_idf_df %>% 
#     group_by(strat_id) %>% # grouping for calculations
#     top_n(20, tf_idf) %>% # pulls out top 20 possible entries for each strat_id based on tf-idf
#     filter(tf_idf != min(tf_idf)) %>% # removing n-grams that have the smallest tf-idf value for each group (prevents over-plotting)
#     filter(!str_detect(n_gram, "\\bNA\\b")) %>% # filtering out lines containing NA as a token 
#     ungroup() %>% # ungroup for plotting
#     mutate(n_gram = reorder(n_gram, tf_idf)) 
#   
# }

