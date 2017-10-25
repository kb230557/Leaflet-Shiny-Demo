#[[RStudio]]

#       Begin each R session by calling the packages that you need with the library() function. Remember that   
#       before you use a package for the first time, you need to install it with install.packages(). In this 
#       tutorial we'll be using the following packages:


library(readxl)  #To import the excel file containing our data
library(rgdal)   #To import our shapefiles
library(dplyr)   #A handy package with lots of useful data manipulation functions
library(leaflet) #To build our interactive map
library(shiny)   #To place that map in an interactive application, responsive to user inputs





#       Let's get started!



#       First, let's import and examine the data we're going to be using. Data in R is stored in objects. You 
#       can store the result of a function in an object by using the assignment operator:  <-
#       In the code below, we are going to use read_excel() (a function from the readxl package) to import a 
#       spreadsheet and save it as an object called "ILI".

#       A special note to Github users: If you'd like to run this code on your own computer, the data files
#       are available in the respository - just remember to change the file paths in this code (there are
#       three of them) to wherever you store the data.


ILI <- read_excel(path = "H:/Special Projects/UIC Demo/ILI_By_Zip_Code_Demo.xlsx")    


#       The ILI data set contains the percent of emergency room visits for influenza like illness(ILI) by zip 
#       code for seven weeks (Week 35 - Week 41).Let's take a look using the glimpse() function! Glimpse() is 
#       from the dplyr package and gives a brief look at the structure of an object.


glimpse(ILI) 


#       Our ILI data is by zip code, so let's import a shapefile of Cook County zip codes. For this, we'll use 
#       readOGR() (a function from the rgdal package).


Zips <- readOGR(dsn = "H:/Special Projects/UIC Demo", layer = "Zip_Code_Demo")


#       Let's see what spatial objects look like in R with glimpse()


glimpse(Zips)


#       Notice that spatial objects in R contain 5 "slots" with information: @data (similar to an attribute table   
#       in ArcGIS),@polygons and @plotOrder (the information needed to draw the shapes), @bbox (the bounding box  
#       for the map), and @proj4string (the coordinate reference system). Let's check the coordinate reference 
#       system of our shapefile to make sure it's compatible with Leaflet's default CRS (WGS 84 / Pseudo-Mercator)


Zips@proj4string


#     The datum of the Zips shapefile is NAD83 which can be considered near-equivalent to WGS84 so we'll leave it  
#     as is. However, the sp package does contain functions for converting shapefiles to different coordinate 
#     reference systems.




#     Now that we have our data, let's make a map with the Leaflet package!



#     Leaflet makes use of the pipe operater %>% which allows you to chain functions together, passing the result 
#     of one function to the next. We start by calling the leaflet() function to initiate a leaflet map widget
#     then use addTiles() to add Leaflet's default background layer, Open Street Map. The setView() function 
#     centers the map where we want it with the preferred zoom level then addPolygons() draws our shapefile on
#     top of the background layer.



leaflet() %>%     #leaflet map widget
  addTiles() %>%      #add background
    setView(lng = -87.86, lat = 41.8, zoom = 10) %>%  #center the map
      addPolygons(data = Zips)   #draw shapefile 



#     Now we have an interactive map!  But unfortunately it doesn't look very pretty and it doesn't contain much 
#     information. Let's see if we can fix that! Let's add some data to our map - remember our ILI file by zip   
#     code? We can join it to the shape file using a join() function from dplyr. But first, let's use dplyr's 
#     filter() function to narrow down our data set to just one week of ILI activity


ILI_40 <- filter(ILI, Week == 40)


#     We want to make sure we join our ILI data to the Zips shapefile's data slot (equivalent to an attribute table).
#     Since the variables that contain zip code in each data object have different names, we need to make sure we tell
#     the function with the by argument.


Zips@data <- left_join(Zips@data, ILI_40, by = c("ZCTA5CE10" = "Zip_Code"))



#     We can see our join worked by checking the structure of the data slot


glimpse(Zips@data)


#     Now we can re-create our leaflet map, this time, shading the color of the polygons based on their ILI activity.
#     First, we need a color palette for our shading. Leaflet contains a number of functions to help create these. 
#     We'll use one where we can set our own intervals (bins) so we know the legend will be the same every time.


pal <- colorBin(palette = "Blues", bins = c(0,1,2,4,6,8,10,Inf))


#     We're going to use the same map from above but this time, we're going to several of the arguments for the 
#     addPolygons() function to customize our map. We'll fill the color of the zip codes using the palette we created 
#     above and each zip code's ILI activity, and make the color slightly transparent. We'll also make the polygon 
#     border a little thinner, completely opaque, and appear as a white, dashed line.
#
#     We're also going to add some highlight options so a polygon's appearance changes slightly when it's moused over.
#     We'll set the label option so data is displayed when moused over too.
#
#     Finally, since we now have some data to display, we'll need a legend. We can add a legend with the addLegend()
#     function and use options to customize it, just like we did with addPolygons(). First, we'll make sure the legend
#     knows what values and colors to display in the legend. Next, we'll set our legend position in the top, right 
#     corner of the map, give it a title, and adjust the display of numbers so they're shown with a % sign.


leaflet() %>%     
  addTiles() %>%     
  setView(lng = -87.86, lat = 41.8, zoom = 10) %>%  
  addPolygons(data = Zips,
    fillColor = ~pal(Zips$Percent_ILI),     #Set color of zip codes 
    fillOpacity = 0.7,     #Set color transparency
    weight = 2,      #Set border width
    opacity = 1,     #Set border transparency
    dashArray = "3", #Set whether line is dashed and what kind of dash
    color = "white", #Set border color
    highlight = highlightOptions(weight = 4, color = "white", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),  #Change appearance on mouse
    label = ~as.character(round(Zips$Percent_ILI, digits = 2))  #Add label on mouse
  )  %>%  
  addLegend(
     pal = pal,    
     values = Zips$Percent_ILI,
     position = "topright",    #Set legend position
     title = "% of ED Visits for ILI",  #Set title
     labFormat = labelFormat(suffix = " %")  #Format number display
  )




#     Now we have a great-looking map of Week 40 ILI activity by zip code that users can interact with. But what if 
#     someone wanted to see data from Week 39? This is where the Shiny package comes in! First, let's reimport the 
#     zip code shapefile so we know we're starting fresh


Zips <- readOGR(dsn = "H:/Special Projects", layer = "Zip_Code_Demo")


#     You can use Shiny to build an application that lets users select what data they want to see, then recreates 
#     the leaflet map with that data. 


#     All Shiny applications have two parts: 
#         1) a ui function (for user interface) that creates the layout of the application and the user controls
#         2) a server function that creates the content based on the user's inputs 


#     Let's build the user interface first


#     We'll nest the parts of our user interface inside a fluidPage() function. This will make the app responsive 
#     to different screen sizes


ui <- fluidPage( 

  
#     First we'll give our user interface a title with headerPanel()
  
  
  headerPanel(title = "Map of ILI Activity by Zip Code"),
  
  
#     I'll include add a little HTML/CSS magic to make sure the map takes up as much vertical space on the screen as 
#     possible


  tags$head(tags$style("#map{height:100vh !important;}")),

  
#     Next we'll take advantage of Shiny's pre-built lay-outs, the most popular of which is sidebarLayout.  
#     SidebarLayout() will create space for two panels:
#         1) a small panel on the left side of the screen for our user controls; content for this panel goes inside
#            a sidebarPanel() function
#         2) and a main panel on the right side of the screen for our display of data (in this case, a map); content 
#            for this panel goes inside a mainPanel() function


  sidebarLayout(
    
    sidebarPanel(
      
      
#     We'll create our user control first. For this app, we're going to create a slider to let users select what 
#     week of data they'd like to see but be aware that Shiny has many other options for controls (e.g. check box,
#     radio button, etc.). The first argument to our slider, inputID, creates a variable that will change every time
#     the user selects a week of data. This variable is used in the server function, so it knows how to re-draw the
#     map. Other arguments let us set a label for our slider, the minimum and maximum range, as well as an initial
#     value to place the slider on at start up.
      

      sliderInput(inputId = "week", 
                  label = "Drag the slider to select a week of data", 
                  min = 35, max = 40, value = 35) 
        
      ),


#     Next we'll create a spot on the user interface for the map inside the main panel. The mainPanel() function 
#     typically contains an output() function. We'll use leafletOutput() since we want to display a Leaflet map
#     We'll only include one argument, the output id, that will be used to link this content to the server function.


    mainPanel(
      leafletOutput(outputId = "map")  
    )
  )
)



#     Now we're ready to make the server function! Server functions must always start with the line below


server <- function(input, output) {

#     We already have a good template for our leaflet map (copied from our previous code). Now we just need to make 
#     it change every time the slider input changes.
#
#     To do this, we'll create the data for the map inside a reactive() function. When placed inside a reactive()
#     function, we can use the variable from the slider input to determine what data should be mapped (and make sure
#     it changes when the slider input changes)

  
  mapdata <- reactive ({
    
    
#     Remember how we filtered our ILI data to select only one week? We'll do the same thing inside the reactive
#     function but instead of manually setting the week to 40, we'll set it to the slider input variable, so the data 
#     will be filtered to whatever the user wants. The return statement makes sure the filtered data gets stored in a
#     reactive data object that we can use to make the map below. 
    
    
      ILI_temp <- filter(ILI, Week == input$week)
      Zips@data <- left_join(Zips@data, ILI_temp, by = c("ZCTA5CE10" = "Zip_Code"))
      return(Zips)                              
  })
  
  
#     Now we can just replace references to Zips in our previous map code with references the reactive mapdata object! 
#     Reactive objects in shiny always have parenthese after their names, like so: mapdata(). We'll also have to nest 
#     our map code inside one of Shiny's family of render() functions so it can be displayed in the user interface.
  

  output$map <- renderLeaflet({
    
      pal <- colorBin(palette = "Blues", bins = c(0,1,2,4,6,8,10,Inf))
    
      leaflet() %>%    
          addTiles() %>%     
          setView(lng = -87.86, lat = 41.8, zoom = 10) %>%  
          addPolygons(data = mapdata(),
              fillColor = ~pal(mapdata()$Percent_ILI), 
              fillOpacity = 0.7, 
              weight = 2, 
              opacity = 1, 
              dashArray = "3", 
              color = "white", 
              highlight = highlightOptions(weight = 4, color = "white", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
              label = ~as.character(round(mapdata()$Percent_ILI), digits = 2)
          )  %>%
      addLegend(
          "topright",
          pal = pal,
          values = mapdata()$Percent_ILI,
          title = "% of ED Visits for ILI",
          labFormat = labelFormat(suffix = " %")
      )
  })
}


#     Last, we can use the shinyApp() function to combine our ui and server functions and see a working instance of 
#     our app!


shinyApp(ui,server)


#     Once you're ready to share your app, you can publish it for free on shinyapps.io
#     https://kcbemis.shinyapps.io/ili_by_zip_code_demo/
  




