module LoomExt::CoreFacts
  class SystemInfoProvider < Loom::Facts::Provider

    using Loom::CoreExt # using +underscore+ for key name creation

    Loom::Facts::Provider.register_factory(self) do |host_spec, shell, loom_config|
      SystemInfoProvider.new host_spec, shell
    end

    def initialize(host_spec, shell)
      @shell = shell
      @namespace = :system_info
    end

    def collect_facts
      # see:
      # https://linux.die.net/man/8/vmstat
      # https://linux.die.net/man/5/proc
      # https://linux.die.net/man/1/df
      # https://www.cyberciti.biz/faq/linux-find-out-raspberry-pi-gpu-and-arm-cpu-temperature-command/
      {
        :vmstat => facts_from_vmstat,
        :loadavg => facts_from_proc_loadavg,
        :df => facts_from_df,
        :os_release => facts_from_etc_os_release,
        :cpu_temp => facts_from_sys_class_thermal_zones
      }
    end

    private
    def facts_from_vmstat
      # NB: requires the host to support `vmstat -s` for table formatted output
      vmstat_table = @shell.capture :vmstat, "-s"
      vmstat_table.each_line.reduce({}) do |memo, line|
        _, str_value, label = line.match(/\s*(\d+)\s(.*)/).to_a
        int_value = str_value.to_i
        value = int_value.to_s == str_value ? int_value : str_value
        memo.merge label.strip.underscore.to_sym => value
      end
    end

    def facts_from_proc_loadavg
      loadavg = @shell.capture :cat, "/proc/loadavg"

      one, five, fifteen, kernel_scheduling_entities, lastpid = loadavg.split
      current_entities, total_entities = kernel_scheduling_entities.split("/")

      {
        :"1_min_avg" => one.to_f,
        :"5_min_avg" => five.to_f,
        :"15_min_avg" => fifteen.to_f,
        :kernel_scheduling_entities => kernel_scheduling_entities,
        :current_scheduling_entities => current_entities.to_i,
        :total_scheduling_entities => total_entities.to_i,
        :lastpid => lastpid
      }
    end

    def facts_from_df
      df = @shell.capture :df

      headers = df.lines.first.split.map do |h|
        h = "UsePercent" if h == "Use%"
        h.strip.underscore.to_sym
      end

      info_lines = df.lines.drop(1).map { |l| l.strip }
      info_lines.map do |info|
        info_parts = info.split.map { |i| i.strip }
        header_info_pairs = headers.zip(info_parts)
        header_info_pairs.reduce({}) do |memo, pair|
          str_value = pair[1]
          int_value = str_value.to_i
          value = int_value.to_s == str_value ? int_value : str_value
          memo.merge pair[0] => value
        end
      end
    end

    def facts_from_etc_os_release
      os_release = @shell.capture :cat, "/etc/os-release"

      facts = {}
      os_release.each_line do |l|
        l = l.strip
        next if l.empty?
        key, value = l.split("=")
        unquoted_value = value.gsub(/^"(.+)"$/) { |m| $1 } rescue ""
        facts[key.to_sym] = unquoted_value
      end
      facts
    end

    def facts_from_sys_class_thermal_zones
      thermal_zones = @shell.capture :ls, "/sys/class/thermal"
      thermal_zones
        .split
        .delete_if { |f| !f.strip.match(/^thermal_zone/) }
        .map do |tz_dir|
        temp = @shell.capture :cat, "/sys/class/thermal/#{tz_dir}/temp"
        temp.strip.to_f / 1000
      end
    end
  end
end
