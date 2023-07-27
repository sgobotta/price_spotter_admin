// assets/js/line_chart.js

// https://www.chartjs.org/docs/3.6.1/getting-started/integration.html#bundlers-webpack-rollup-etc
import Chart from 'chart.js/auto'

// A wrapper of Chart.js that configures the realtime line chart.
export default class {
  constructor(ctx) {
    this.colors = [
      'rgba(74, 222, 128, 1)'
    ]

    const config = {
      type: 'line',
      data: {labels: [], datasets: []},
      options: {
        datasets: {
          // https://www.chartjs.org/docs/3.6.0/charts/line.html#dataset-properties
          line: {
            tension: 0.09
          }
        },
        plugins: {
          // https://nagix.github.io/chartjs-plugin-streaming/2.0.0/guide/options.html
          streaming: {
            duration: 60 * 1000,
            delay: 1500
          }
        },
        scales: {
          x: {
            // chartjs-plugin-streaming
            suggestedMin: 50,
            suggestedMax: 200
          },
          y: {
            suggestedMin: 50,
            suggestedMax: 200
          }
        }
      }
    }

    this.chart = new Chart(ctx, config)
  }

  addPoint(data_label, label, value, backgroundColor, borderColor) {   
    this.chart.config.data.labels.push(data_label)
    const dataset = this._findDataset(label) || this._createDataset(label, backgroundColor, borderColor)
    dataset.data.push({x: Date.now(), y: value})
    this.chart.update()
  }

  destroy() {
    this.chart.destroy()
  }

  _findDataset(label) {
    return this.chart.data.datasets.find((dataset) => dataset.label === label)
  }

  _createDataset(label, backgroundColor, borderColor) {
    const newDataset = {label, data: [], borderColor: borderColor, fill: 'origin', backgroundColor: backgroundColor}
    this.chart.data.datasets.push(newDataset)
    return newDataset
  }
}
