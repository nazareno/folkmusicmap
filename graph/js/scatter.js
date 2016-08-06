
// load asynrously
d3.json("song_info.json", function(json) {
  data = read_tsne_json(json);

  add_graph(data);
  d3.selectAll(".nv-point").on("click", function(e) {console.log(JSON.stringify(e));});
});


function add_graph(data) {
  nv.addGraph(function() {
    var chart = nv.models.scatterChart()
                  .showDistX(false)    //showDist, when true, will display those little distribution lines on the axis.
                  .showDistY(false)
                  .transitionDuration(350)
                  .forceY([-30,30])
                  .forceX([-30,30])
                  .color(d3.scale.category10().range());

    //Configure how the tooltip looks.
    chart.tooltipContent(function(key, x, y) {
        return '<h3>' + key + " "+ x + " " + y +';</h3>';
    });

    //Axis settings
    chart.xAxis.tickFormat(d3.format('.02f'));
    chart.yAxis.tickFormat(d3.format('.02f'));

    //We want to show shapes other than circles.
    chart.scatter.onlyCircles(true);


    // Random data
    // var data = randomData(4,40);

    d3.select('#chart svg')
        .datum(data)
        .call(chart);

    nv.utils.windowResize(chart.update);
    return chart;

  });
}



/**************************************
 * Simple test data generator
 */
function randomData(groups, points) { //# groups,# points per group
  var data = [],
      shapes = ['circle', 'cross', 'triangle-up', 'triangle-down', 'diamond', 'square'],
      random = d3.random.normal();

  for (i = 0; i < groups; i++) {
    data.push({
      key: 'Group ' + i,
      values: []
    });

    for (j = 0; j < points; j++) {
      data[i].values.push({
        x: random()
      , y: random()
      , size: Math.random()   //Configure the size of each scatter point
      , shape: (Math.random() > 0.95) ? shapes[j % 6] : "circle"  //Configure the shape of each scatter point.
      });
    }
  }

  return data;
}



function read_tsne_json(json) {

  var data = [];
  var shapes = ['circle'];

  var groups = {};

  json.forEach(function(song, i) {
    // group_by = song.region;
    group_by = song.region;
    if (!groups[group_by]) {
      console.log("adding region: " + group_by);
      // add group
      groups[group_by] = {key: group_by,
                             values: []};
    }

    groups[group_by].values.push({
       x: song.x,
       y: song.y,
       size: song.Distance,
       shape: "circle",
       audio_url: song.SampleAudio
    });
  });

  for (var key in groups) {
    data.push(groups[key]);
  }

  the_data = data;
  return data;
}
