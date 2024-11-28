# Load required libraries
library(shiny)
library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(plotly)
library(zoo) # For moving average
library(splines) # For spline smoothing

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Define the UI
ui <- fluidPage(
  titlePanel("Interactive CFR Visualization for Hypothetical T Values"),
  
  sidebarLayout(
    sidebarPanel(
      # Country selection dropdown
      selectInput("country", "Select Country:",
                  choices = c("Democratic Republic of Congo", "United States"),
                  selected = "Democratic Republic of Congo"),
      
      # Toggle between modes
      radioButtons("mode", "Select Mode:",
                   choices = list("Slider Mode" = "slider", 
                                  "Overlay Mode" = "overlay", 
                                  "CI Mode (95%)" = "ci"),
                   selected = "slider"),
      
      # Controls for slider mode
      conditionalPanel(
        condition = "input.mode == 'slider'",
        sliderInput("T_value", 
                    "Select Hypothetical T Value:",
                    min = 0, 
                    max = 30, 
                    value = 23, 
                    step = 1)
      ),
      
      # Controls for overlay mode
      conditionalPanel(
        condition = "input.mode == 'overlay'",
        checkboxGroupInput("T_values_overlay", 
                           "Select T Values for Overlay:",
                           choices = 0:30,
                           selected = c(5, 15, 23)) # Default selected T values
      ),
      
      # Smoothing method selection
      selectInput("smoothing", "Select Smoothing Method:",
                  choices = c("Raw" = "raw", 
                              "7-Day Moving Average" = "moving_avg", 
                              "Loess Smoothing" = "loess", 
                              "Spline Smoothing" = "spline"),
                  selected = "raw"),
      
      # Date range selector (common for all modes)
      dateRangeInput("date_range", 
                     "Select Date Range:",
                     start = "2022-01-01", 
                     end = "2024-12-31",
                     min = "2022-01-01", 
                     max = "2024-12-31"),
      
      width = 3
    ),
    
    mainPanel(
      plotlyOutput("cfr_plot"),
      width = 9
    )
  )
)

# Define the server logic
server <- function(input, output) {
  # Reactive expression to filter and preprocess the data
  filtered_data <- reactive({
    # Load and preprocess the data
    drc_data <- readRDS("./rds/drc_data.rds")
    
    # Filter for the selected country
    drc_data <- drc_data %>%
      filter(Country == input$country)
    
    # Convert 'Day' column to Date format
    drc_data$Day <- as.Date(drc_data$Day, origin = "1899-12-30")
    
    # Rename relevant columns
    drc_data <- drc_data %>%
      rename(
        daily_cases = `Daily cases`,
        total_cases = `Total confirmed cases`,
        daily_deaths = `Daily deaths`,
        total_deaths = `Total deaths`
      )
    
    # Ensure numeric columns
    drc_data$daily_cases <- as.numeric(drc_data$daily_cases)
    drc_data$daily_deaths <- as.numeric(drc_data$daily_deaths)
    
    # Apply smoothing methods based on user selection
    if (input$smoothing == "raw") {
      drc_data <- drc_data %>%
        mutate(daily_deaths_smoothed = daily_deaths)
    } else if (input$smoothing == "moving_avg") {
      drc_data <- drc_data %>%
        mutate(daily_deaths_smoothed = zoo::rollmean(daily_deaths, 7, fill = NA, align = "right"))
    } else if (input$smoothing == "loess") {
      drc_data <- drc_data %>%
        filter(!is.na(daily_deaths), !is.na(Day)) %>% # Remove rows with missing data
        mutate(daily_deaths_smoothed = predict(loess(daily_deaths ~ as.numeric(Day), data = ., span = 0.1)))
    } else if (input$smoothing == "spline") {
      drc_data <- drc_data %>%
        mutate(daily_deaths_smoothed = spline(Day, daily_deaths, xout = Day)$y)
    }
    
    # Handle NA values before applying cumsum
    drc_data <- drc_data %>%
      mutate(
        daily_deaths_smoothed = ifelse(is.na(daily_deaths_smoothed), 0, daily_deaths_smoothed),
        total_cases = cumsum(daily_cases),
        total_deaths = cumsum(daily_deaths_smoothed)
      )
    
    # Filter data based on user-selected date range
    drc_data <- drc_data %>%
      filter(Day >= input$date_range[1] & Day <= input$date_range[2])
    
    drc_data
  })
  
  
  # Reactive expression to calculate CFR for the selected mode
  cfr_calculated <- reactive({
    drc_data <- filtered_data()
    
    if (input$mode == "slider") {
      # Slider mode: Calculate CFR for a single T value
      T <- as.integer(input$T_value)  # Ensure T is an integer
      drc_data <- drc_data %>%
        arrange(Day) %>%
        mutate(
          shifted_total_cases = lag(total_cases, n = T),
          CFR = total_deaths / shifted_total_cases * 100
        ) %>%
        filter(!is.na(CFR), shifted_total_cases > 0, is.finite(CFR)) # Remove invalid rows
      
      drc_data$T <- T # Add T value column for plotting
      return(drc_data)
      
    } else if (input$mode == "overlay") {
      # Overlay mode: Calculate CFR for multiple T values
      T_values <- input$T_values_overlay
      if (is.null(T_values) || length(T_values) == 0) {
        # If no T values are selected, return an empty data frame
        return(data.frame())
      }
      
      cfr_list <- list()
      for (T in T_values) {
        T <- as.integer(T)  # Ensure T is an integer
        cfr_temp <- drc_data %>%
          arrange(Day) %>%
          mutate(
            shifted_total_cases = lag(total_cases, n = T),
            CFR = total_deaths / shifted_total_cases * 100,
            T = as.factor(T) # Convert T to factor for coloring
          ) %>%
          filter(!is.na(CFR), shifted_total_cases > 0, is.finite(CFR)) # Remove invalid rows
        
        cfr_list[[as.character(T)]] <- cfr_temp
      }
      
      # Combine all T-value data frames into one
      cfr_combined <- bind_rows(cfr_list)
      return(cfr_combined)
      
    } else if (input$mode == "ci") {
      # CI mode: Calculate 95% confidence interval from all T values (0 to 30)
      T_values <- 0:30
      cfr_list <- list()
      
      for (T in T_values) {
        T <- as.integer(T)
        cfr_temp <- drc_data %>%
          arrange(Day) %>%
          mutate(
            shifted_total_cases = lag(total_cases, n = T),
            CFR = total_deaths / shifted_total_cases * 100
          ) %>%
          filter(!is.na(CFR), shifted_total_cases > 0, is.finite(CFR)) # Remove invalid rows
        
        cfr_list[[as.character(T)]] <- cfr_temp %>% select(Day, CFR)
      }
      
      # Combine data and calculate quantiles for 95% CI
      cfr_combined <- bind_rows(cfr_list) %>%
        group_by(Day) %>%
        summarise(
          mean_CFR = mean(CFR, na.rm = TRUE),
          lower_CI = quantile(CFR, 0.025, na.rm = TRUE),
          upper_CI = quantile(CFR, 0.975, na.rm = TRUE)
        ) %>%
        ungroup()
      
      return(cfr_combined)
    }
  })
  
  # Render the interactive plot
  output$cfr_plot <- renderPlotly({
    cfr_data <- cfr_calculated()
    
    if (nrow(cfr_data) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
               layout(title = "No Data Available for Selected T Values"))
    }
    
    if (input$mode == "slider") {
      # Single line for slider mode
      cfr_plot <- ggplot(cfr_data, aes(x = Day, y = CFR)) +
        geom_line(color = "blue", size = 1) +
        ylim(0, 0.6) +
        labs(
          title = paste("CFR Over Time for Hypothetical T =", input$T_value),
          x = "Date",
          y = "Case Fatality Rate (%)"
        ) +
        theme_minimal()
      
    } else if (input$mode == "overlay") {
      # Multiple lines for overlay mode
      cfr_plot <- ggplot(cfr_data, aes(x = Day, y = CFR, color = T, group = T)) +
        geom_line(size = 1) +
        ylim(0, 0.6) +
        scale_color_viridis_d(name = "T Values") + # Better color palette for overlay mode
        labs(
          title = paste("CFR Over Time for", input$country),
          x = "Date",
          y = "Case Fatality Rate (%)"
        ) +
        theme_minimal()
      
    } else if (input$mode == "ci") {
      # CI mode: Plot mean CFR with 95% confidence interval
      cfr_plot <- ggplot(cfr_data, aes(x = Day)) +
        geom_ribbon(aes(ymin = lower_CI, ymax = upper_CI), fill = "lightblue", alpha = 0.4) +
        geom_line(aes(y = mean_CFR), color = "blue", size = 1) +
        ylim(0, 0.6) +
        labs(
          title = paste("95% CI for CFR Over Time for", input$country),
          x = "Date",
          y = "Case Fatality Rate (%)"
        ) +
        theme_minimal()
    }
    
    # Convert ggplot to Plotly for interactivity
    ggplotly(cfr_plot)
  })
}

# Run the Shiny app
shinyApp(ui = ui, server = server)
