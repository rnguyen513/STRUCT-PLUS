#  Struct-Plus: real time rectangle detection and stress simulation tool

Developed for the UVA I2SEE Civil Engineering Lab. [Video demo here.](https://myuva-my.sharepoint.com/:v:/g/personal/amk3ef_virginia_edu/EWDdMhxRc8tFphwOwS91bWAB_PJXMm6XiB8PhvGzCkYO3g?e=ji3auC)
![download (1)](https://github.com/rnguyen513/STRUCT-PLUS/assets/77138030/f41a359a-a505-4d48-b9dc-627023541e78)
![download (2)](https://github.com/rnguyen513/STRUCT-PLUS/assets/77138030/de0a7d1a-0dda-4ae0-a65e-b6514882d1ad)



###  <ins>What?</ins>
A WIP proof of concept for 2D rectangle objection detection and automated stress simulation with convolutional neural network.

### <ins>How?</ins>
First, AR scene is initialized, then tap gesture recognizer is created so the user can select a rectangle (rectangle is found using VNDetectRectanglesRequest, finally backend TensorFlow Lite model is called to run inference. When the inference is complete, the results are drawn back to the screen in the form of an overlay to the selected rectangle. Model latency in its lite form is <0.5s. This tool is efficient for real time analysis.


###  <ins>Pros</ins>

+Lightweight & quick realtime simulation for preliminary analysis

+Customizable loading conditions in the X- and Y-directions

+Can be LIDAR-enhanced to work well even in low light environments

###  <ins>Cons</ins>

-Currently limited to rectangles. However, Apple offers a library that tracks preloaded models which might be a means of detecting regular objects. This is future work.

-Developed for Apple hardware only. Haven't really heard of Android equivalents to the same libraries and capabilities that Apple has.
