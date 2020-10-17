#=
 * Mandelbrot with Text
 *
 * Typical View:
 *  X=-1 -> +2
 *  Y= -1.5->+1.5
 *
 * f(x)=x^2-u
 *   Where x is a complex number and so is u.
 *
 *    u is the current position on the grid
 *
 *   color is determined by how fast the function
 *   a converges.  If the function converges, paint
 *   black otherwise assign a color.
 *
 *   How many iterations should be attempted?
 *
=#


using Printf
#using Distributed 
using Gtk.ShortNames, Graphics
using Base.Threads

function ColorImage(sem) 

  num_threads = Threads.nthreads()
  increment = image["length"] / image["pixels_per_side"]
  
# Distributed
#  @distributed for it= 1:num_threads
#    iy = floor(Int64,(image["pixels_per_side"]/num_threads))
#    di= image["min_y"] + (iy*(it-1))*increment 
#    ColorImageRow(increment,di,(iy*(it-1))+1,iy*(it)) 
#  end 

# Theads
  @Threads.threads for it= 1:num_threads

    # Need to have single file nature , so output is not scranbled 
    lock(sem)
    @printf("Thread ID %d is starting\n", Threads.threadid()) 
    unlock(sem)

#    lock(c)
#    try
#      @printf("Thread ID %d", Threads.threadid()) 
#    finally
#      unlock(c)
#    end

    iy = floor(Int64,(image["pixels_per_side"]/num_threads))
    di= image["min_y"] + (iy*(it-1))*increment 
    ColorImageRow(increment,di,(iy*(it-1))+1,iy*(it)) 
  end
  return nothing
end

function ColorImageRow(increment,di,first_y,num_y) 

#  @printf("Thread ID %d",Threads.threadid()) 
  c=image["min_x"] # is this needed?
  for iy= first_y:num_y
    for ix= 1:image["pixels_per_side"]
      #@printf("ix:%d,iy:%d",ix,iy) 
      if ix == 1
	c=image["min_x"]
      else
	c=c+increment
      end 
      if ((ix == 1) && (iy == 1))
	di= image["min_y"]
      elseif ix == 1 
	di=di + increment
      end
      color = GetColor(c,di)
      #@printf("color: %d",color)
      idata[ix,iy] =  color
    end 
  end 
  return nothing
end

function PrintImage()

  for iy = 1:floor(Int64,image["pixels_per_side"]/image["pixel_step"])
    PrintImageLine(iy)
  end
  return nothing
end

function PrintImageLine(iy)

  for ix= 1:floor(Int64,image["pixels_per_side"]/image["pixel_step"])
    #@printf("ix%d:iy%d\n",ix,iy)
    dot=idata[ix*image["pixel_step"],iy*image["pixel_step"]]
    dot=(dot % 8)
    @printf("%s",text_color[(dot+1)])
  end 
  @printf ("\n")
  return nothing
end

function GetColor(c,di)

  threshold=1000.0
  a = 0.0
  bi = 0.0
  val=0
  # @printf("c:%5.3f di:%5.3f\n",c,di)
  for i = 0:image["num_iterations"]
    if i==0 
	a=c
	bi=di
    else
	# (a+bi)(a+bi)-(c+di) = a^2 - b^2 -c + 2*a*bi -di
	new_a = (a*a - bi*bi - c)
	new_bi = (2*a*bi-di)
	a=new_a
	bi=new_bi
    end 
    if a>threshold 
      return(val);
    end 
    val=val+1
  end 
  return(val);
end
#
# Initialize Semaphore
#
# create (exclusive)
sem = SpinLock()

#
# Initialize Image Metadata
#
image = Dict("pixels_per_side"=>0, # assign later
    "min_x"=>-1.0,
    "min_y"=>-1.5,
    "length"=> 3.0,
    "bits_per_color"=> 4,
    "pixel_step"=> 64,
    "num_iterations"=> 0.0 # assign later
  )
# 3 for RBG
image["num_iterations"] = (2^(image["bits_per_color"]*3))
image["pixels_per_side"] = 16*image["pixel_step"]

#
# Initialize Image Data
#
idata = zeros(Int32,image["pixels_per_side"],image["pixels_per_side"])

#
# Define Color Characters
#
text_color = ".-=!^(@%"

#
# Number of threads 
#
@printf("Number of threads %d\n", Threads.nthreads())

#
# Compute Mandelbrot
#
ColorImage(sem)

# 
# Display Results
#
PrintImage()

# 
# Draw 
#
canvas = @Canvas(image["pixels_per_side"],image["pixels_per_side"])
win = Window(canvas, "Canvas",image["pixels_per_side"],image["pixels_per_side"])
h=0
w=0
@guarded draw(canvas) do widget 
  ctx = getgc(canvas)
  h = height(canvas)
  w = width(canvas)
  for ix = 1:image["pixels_per_side"]
    for iy = 1:image["pixels_per_side"]
      color = idata[ix,iy]
#=
      red = convert(AbstractFloat,(color & 0xF)) / 16 
      green = convert(AbstractFloat,((color>>4) & 0xF)) / 16 
      blue = convert(AbstractFloat,((color>>8) & 0xF)) / 16 
=#
      blue = convert(AbstractFloat,(color & 0xF)) / 16 
      red = convert(AbstractFloat,((color>>4) & 0xF)) / 16 
      green = convert(AbstractFloat,((color>>8) & 0xF)) / 16 
      set_source_rgb(ctx,red,green,blue)
      rectangle(ctx,(ix-1),(iy-1),1,1)
      fill(ctx)
    end
  end
end
show(canvas)

#
# Mouse Callback
#
  canvas.mouse.button1press = @guarded (widget, event) -> begin
    ctx = getgc(widget)
    @printf("x: %d , y: %d\n", event.x,event.y)
  end
  canvas.mouse.button3press = @guarded (widget, event) -> begin
    ctx = getgc(widget)
    quitNow = true
  end

#
# Define the popup menu
#
#=
    popupmenu = @Menu(pop)
    miQuit = @MenuItem("Quit")
    push!(popupmenu, muQuit)
    push!(popupmenu, @MenuItem("Do nothing"))
    # This next line is crucial: otherwise your popup menu shows as a thin bar
    showall(popupmenu)
    # Associate actions with right-click and selection
    canvas.mouse.button3press = (widget,event) -> popup(popupmenu, event)
    signal_connect(miQuit, :activate) do widget
        quitNow = true 
    end
=#

#
# Menus
#

#file = @MenuItem("_File")
#filemenu = @Menu(file)
#quit = @MenuItem("Quit")
#push!(filemenu,quit)
#mb = @MenuBar()
#push!(mb,file)
#showall(mb)

quitNow = false
while (quitNow == false) 
  sleep(1)
end

