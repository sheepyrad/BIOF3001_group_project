# Load required libraries
library(shiny)
library(openxlsx)
library(ggplot2)
library(plotly)
library(dplyr)
library(zoo) 

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Load the data
transmissibility_USA <- readRDS("./rds/transmissibility_USA.rds")
transmissibility_DRC <- readRDS("./rds/transmissibility_DRC.rds")
transmissibility_UG <- readRDS("./rds/transmissibility_UG.rds")
transmissibility_BU <- readRDS("./rds/transmissibility_BU.rds")
mpox_data <- readRDS("./rds/mpox_data.rds")

# Create a mapping between input values and actual country names in the data
country_mapping <- list(
  "USA" = "United States",
  "DRC" = "Democratic Republic of Congo",
  "UG" = "Uganda",
  "BU" = "Burundi"
)

# Define the UI
ui <- fluidPage(
  titlePanel("Interactive Visualization of Daily Cases and Reproduction Number (R)"),
  
  sidebarLayout(
    sidebarPanel(
      radioButtons("country", "Select Country:",
                   choices = list("USA" = "USA", "DRC" = "DRC", "UG" = "UG", "BU" = "BU"),
                   selected = "USA",
                   inline = TRUE), # Reduce size by making inline
      width = 2 # Reduce sidebar width
    ),
    
    mainPanel(
      plotlyOutput("interactivePlot", height = "800px"), # Increase plot size
      width = 10 # Increase main panel width
    )
  )
)

# Define the server logic
server <- function(input, output) {
  output$interactivePlot <- renderPlotly({
    # Map the input country to the actual country name in the data
    actual_country <- country_mapping[[input$country]]
    
    # Get the data for the selected country
    data_Rt <- switch(input$country,
                      "USA" = transmissibility_USA,
                      "DRC" = transmissibility_DRC,
                      "UG" = transmissibility_UG,
                      "BU" = transmissibility_BU)
    
    data_incidence <- mpox_data %>% filter(Country == actual_country)
    
    # Set country-specific colors and labels
    country_name <- actual_country
    color <- switch(input$country,
                    "USA" = "blue",
                    "DRC" = "darkgreen",
                    "UG" = "purple",
                    "BU" = "orange")
    fill_color <- switch(input$country,
                         "USA" = "lightblue",
                         "DRC" = "lightgreen",
                         "UG" = "violet",
                         "BU" = "gold")
    
    # Calculate a 7-day moving average for daily cases
    data_incidence <- data_incidence %>%
      arrange(Day) %>%
      mutate(rollavg = zoo::rollmean(Daily.cases, 7, fill = NA, align = "right"))
    # Create the incidence plot
    fig_incidence <- plot_ly(data_incidence, x = ~Day) %>%
      add_bars(y = ~Daily.cases, name = "Daily Cases", marker = list(color = 'grey')) %>%
      add_lines(y = ~rollavg, name = "7-day Average", line = list(color = color, width = 2)) %>%
      layout(
        yaxis = list(title = "Daily Cases"),
        xaxis = list(title = "Date", type = 'date'),
        showlegend = TRUE
      )
    
    # Create the Rt plot
    fig_Rt <- plot_ly(data_Rt, x = ~t_end) %>%
      add_ribbons(ymin = ~`Quantile.0.025(R)`, ymax = ~`Quantile.0.975(R)`,
                  fillcolor = fill_color, line = list(color = 'transparent'),
                  hoverinfo = "none", name = "95% Confidence Interval", opacity = 0.5) %>%
      add_lines(y = ~`Mean(R)`, line = list(color = color, width = 2),
                name = "Mean R", hoverinfo = "x+y") %>%
      add_lines(x = ~t_end, y = 1, line = list(color = 'red', dash = 'dash', width = 1),
                name = "R=1", hoverinfo = "none") %>%
      layout(
        yaxis = list(title = "Reproduction Number (R)"),
        xaxis = list(title = "Date", type = 'date'),
        showlegend = FALSE  # Hide legend to avoid duplication
      )
    
    # Combine the plots into a single figure arranged vertically
    fig <- subplot(fig_incidence, fig_Rt, nrows = 2, shareX = TRUE, titleY = TRUE, margin = 0.1) %>%
      layout(
        title = paste("Daily Cases and Reproduction Number (R) Over Time (", country_name, ")", sep = ""),
        margin = list(t = 80, b = 50),
        xaxis = list(
          title = "Date",
          type = 'date',
          rangeslider = list(visible = TRUE),
          rangeselector = list(
            buttons = list(
              list(count = 7, label = "1 Week", step = "day", stepmode = "backward"),
              list(count = 1, label = "1 Month", step = "month", stepmode = "backward"),
              list(count = 3, label = "3 Months", step = "month", stepmode = "backward"),
              list(step = "all", label = "All Time")
            )
          )
        ),
        legend = list(orientation = "h", x = 0.5, y = -0.1, xanchor = "center")  # Adjust legend position if needed
      )
    
    fig
  })
}

# Run the Shiny app
shinyApp(ui = ui, server = server)


