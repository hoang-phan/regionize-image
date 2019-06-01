require 'rmagick'
include Magick

class Regionizer
  attr_reader :image, :columns, :rows, :regions, :lookup, :reverse_region_lookup, :borders

  THRESHOLD = 5

  COLORS = %w[red green blue orange purple brown white black yellow]

  def initialize(image)
    @image = image
    @columns = image.columns
    @rows = image.rows
    @regions = {}
    @reverse_region_lookup = { -1 => {}, columns => {} }
    @lookup = []
    @borders = { -1 => {} }
    
    @lookup =
      columns.times.map do |x|
        reverse_region_lookup[x] = {}
        borders[x] = {}

        rows.times.map do |y|
          pixel = image.pixel_color(x, y)
          pixel2lab(pixel)
        end
      end
  end

  def call
    regionize_columns
    regionize_rows
    check_borders_rows
    check_borders_columns
  end

  def to_image
    new_image = Image.new(columns, rows)
    white_pixel = Pixel.from_color('white')
    black_pixel = Pixel.from_color('black')

    columns.times do |x|
      rows.times do |y|
        new_image.pixel_color(x, y, borders[x][y] ? black_pixel : white_pixel)
      end
    end

    new_image
  end

  private

  def regionize_columns
    region_index = 0

    columns.times do |x|
      current_point = nil
      regions[region_index] = []

      rows.times do |y|
        next_point = [x, y]

        if !current_point || diff(current_point, next_point) <= THRESHOLD
          current_point = next_point
          regions[region_index] << current_point
          reverse_region_lookup[x][y] = region_index
          next
        end

        region_index += 1
        current_point = next_point
        regions[region_index] = [current_point]
        reverse_region_lookup[x][y] = region_index
      end

      current_point = nil
      region_index += 1
    end
  end

  def regionize_rows
    rows.times do |y|
      current_point = nil

      columns.times do |x|
        next_point = [x, y]

        if !current_point
          current_point = next_point
          next
        end

        if diff(current_point, next_point) <= THRESHOLD
          merge_regions(current_point, next_point)
          current_point = next_point
          next
        end

        current_point = next_point
      end
    end
  end

  def check_borders_rows
    rows.times do |y|
      current_region = nil

      columns.times do |x|
        next_region = reverse_region_lookup[x][y]
        if current_region != next_region
          borders[x][y] = true 
          borders[x - 1][y] = true
        end
        current_region = next_region
      end
    end
  end

  def check_borders_columns
    columns.times do |x|
      current_region = nil

      rows.times do |y|
        next_region = reverse_region_lookup[x][y]
        if current_region != next_region
          borders[x][y] = true
          borders[x][y - 1] = true
        end
        current_region = next_region
      end
    end
  end

  def merge_regions(point1, point2)
    x1, y1 = point1
    x2, y2 = point2
    ri1 = reverse_region_lookup[x1][y1]
    ri2 = reverse_region_lookup[x2][y2]
    return if ri1 == ri2

    regions[ri2].each do |point|
      x, y = point
      reverse_region_lookup[x][y] = ri1
      regions[ri1] << point
    end
    regions.delete(ri2)
  end

  def diff(point1, point2)
    x1, y1 = point1
    x2, y2 = point2
    l1, a1, b1 = lookup[x1][y1]
    l2, a2, b2 = lookup[x2][y2]
    Math.sqrt((l1 - l2) ** 2 + (a1 - a2) ** 2 + (b1 - b2) ** 2)
  end

  def pixel2lab(pixel)
    r = pixel.red / 65535.0
    g = pixel.green / 65535.0
    b = pixel.blue / 65535.0

    r = (r > 0.04045) ? ((r + 0.055) / 1.055) ** 2.4 : r / 12.92;
    g = (g > 0.04045) ? ((g + 0.055) / 1.055) ** 2.4 : g / 12.92;
    b = (b > 0.04045) ? ((b + 0.055) / 1.055) ** 2.4 : b / 12.92;

    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

    x = (x > 0.008856) ? x ** (1 / 3.0) : (7.787 * x) + 16 / 116.0;
    y = (y > 0.008856) ? y ** (1 / 3.0) : (7.787 * y) + 16 / 116.0;
    z = (z > 0.008856) ? z ** (1 / 3.0) : (7.787 * z) + 16 / 116.0;

    [(116 * y) - 16, 500 * (x - y), 200 * (y - z)]
  end
end

file_full = ARGV[0].strip
file_name, extension = file_full.split('.')
regionizer = Regionizer.new(Image.read(file_full).first)
regionizer.call
regionizer.to_image.write("#{file_name}_regionized.#{extension}")
