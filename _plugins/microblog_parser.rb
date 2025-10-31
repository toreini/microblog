require 'yaml'

module Jekyll
  class MicroblogGenerator < Generator
    safe true
    priority :low

    def generate(site)
      file = File.join(site.source, '_data', 'microblogs.md')
      return unless File.exist?(file)

      raw_content = File.read(file)
      posts = raw_content.split(/^---\s*$/).reject(&:empty?).map do |entry|
        begin
          if entry =~ /\A\s*(---\s*\n.*?\n?)^(---\s*$\n?)/m
            front_matter = YAML.safe_load(entry[/\A---\s*\n(.*?)\n---/m, 1]) || {}
            content = entry.sub(/\A---\s*\n(.*?)\n---/m, '').strip
            {
              'title' => front_matter['title'] || 'Untitled',
              'date'  => front_matter['date'] ? Date.parse(front_matter['date'].to_s) : Date.today,
              'tags'  => front_matter['tags'] || [],
              'content' => content
            }
          end
        rescue => e
          Jekyll.logger.warn "MicroblogParser:", "Error parsing entry: #{e}"
          nil
        end
      end.compact

      site.data['microblogs'] = posts.sort_by { |p| p['date'] }.reverse

      # Collect all tags
      all_tags = posts.flat_map { |p| p['tags'] }.uniq.compact

      # Generate a tag page for each tag
      all_tags.each do |tag|
        site.pages << TagPage.new(site, site.source, tag, posts)
      end
    end
  end

  class TagPage < Page
    def initialize(site, base, tag, posts)
      @site = site
      @base = base
      @dir  = File.join('tags', tag.downcase.strip.gsub(' ', '-'))
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'tag.html')

      self.data['tag'] = tag
      self.data['title'] = "Posts tagged ##{tag}"
      self.data['posts'] = posts.select { |p| p['tags']&.include?(tag) }
    end
  end
end
