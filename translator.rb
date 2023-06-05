$commands = ["MOV", "ADC", "IDIV","JGE", "INT"]
$baseRegisters = ["BP", "BX"]
$current_loc = 0
$segmentStart_loc = 0
$segmentEnds_loc = 0
$flag = 0
$orgsize = 0
$jgeloc = -1
$listing = []
$segmentName = ""
$machineCode = []
$register_codes = {
  "AX" => "000",
  "BX" => "011",
  "CX" => "001",
  "DX" => "010",
  "SI" => "110",
  "DI" => "111",
  "BP" => "101",
  "SP" => "100"
}
$metas = ["SEGMENT", "ORG" , "ENDS","END"]

$current_line_number=1
class Operand
    attr_accessor :type, :value
    def initialize(type, value)
        @type = type
        @value = value
      end 
end
class Label
    attr_accessor :address, :name
    def initialize(address,name)
        @address = address
        @name = name
    end 
end  
class Var
    attr_accessor :address, :name, :value
    def initialize(address,name,value)
        @address = address
        @name = name
        @value = value
    end 
end  
$metaLabel = Label.new(-1,"")
class Parser
  attr_accessor :filename

  def initialize(filename)
    @filename = filename
  end

  def parse
    File.open(@filename, "r") do |file|
      file.each_line do |line|
        next if line.strip.empty?  # Пропустить пустые строки
        line = line.strip
        line = line.upcase
        status = detect_instruction(line)
        case status
        when "directive"
            split_line = line.strip.split(/[,\s]+/)
            command = detect_directive(split_line[0])
            case command 
                when "ORG"
                    operand = detect_operand_type(split_line[1])
                    ORG(operand)
                when "SEGMENT"
                    operand = detect_operand_type(split_line[1])
                    SEGMENT(operand)
                when "ENDS"
                    operand = detect_operand_type(split_line[1])
                    ENDS(operand)
                when "END"
                    operand = detect_operand_type(split_line[1])
                    ENDPROG()
                else 
                    return "ERORR"
                end
        when "instruction"
            split_line = line.strip.split(/[,\s]+/)
            command = detect_command(split_line[0])
            
            if split_line.length == 2
              # Инструкция с одним операндом
                detect_commandInstructionOneOpernads(split_line)
            elsif split_line.length == 3
                detect_commandInstructionTwoOpernads(split_line)
              # Обработка инструкции с двумя операндами
            else
                erorrsWriter("Ошибка! Транслятор не смог распознать команду: #{command} с количеством операндов #{split_line.length-1}, строка : #{$current_line_number}")
            end 
        when "label"
            split_line = line.strip.split(/[,\s]+/)       
            label = Label.new($current_loc,split_line[0] )
            LABEL(label)
        when "var"
            split_line = line.strip.split(/[,\s]+/)       
            var = Var.new($current_loc,split_line[0],split_line[2])
            DW(var)
        else
          return "ERROR type"
        end 
      end
    end
  end

  def detect_commandInstructionTwoOpernads(split_line)
    first_operand = detect_operand_type(split_line[1])
    second_operand = detect_operand_type(split_line[2])
    split_line[0] == "MOV" ? MOV(first_operand,second_operand) : ADC(first_operand,second_operand)
  end


  def detect_commandInstructionOneOpernads(split_line)
    first_operand = detect_operand_type(split_line[1])
    split_line[0] == "IDIV" ? IDIV(first_operand) : split_line[0] == "INT" ? INT(first_operand) : JGE(first_operand)
  end


  def detect_instruction(line)
    split_line = line.strip.split(/[,\s]+/)
    instructions = split_line[0]
  
    if $metas.include?(instructions)
      # Директива сегмента или организации программы
      return "directive"
    elsif $commands.include?(instructions)
      # Инструкция MOV, ADC, IDIV, JGE
      return "instruction"
    elsif line.include?(":")
    # метка
      return "label"
    elsif line.include?("DW")
    # метка
      return "var"
    else
        erorrsWriter("Ошибка! Транслятор не смог распознать команду: #{instructions}, строка : #{$current_line_number}")
    end
  end
  
  

  def detect_operand_type(operand)
    operand = operand.to_s
    characters = operand.chars
    if $register_codes.key?(operand)
      return Operand.new("register", operand)
    elsif characters.first == "[" && characters.last == "]"
      return Operand.new("memory", operand)
    else
      return Operand.new("direct", operand)
    end
  end
  

  def detect_command(command_name)
    if $commands.include?(command_name)
      return command_name
    else
        erorrsWriter("Ошибка! Транслятор не смог распознать команду: #{command_name}, строка : #{$current_line_number}")
    end
  end


  def detect_directive(command_name)
    if $metas.include?(command_name)
      return command_name
    else
        erorrsWriter("Ошибка! Транслятор не смог распознать команду: #{command_name}, строка : #{$current_line_number}")
    end
   end


end
    def MOV(first,second)
         
        result =""
        if first.type == "register" && second.type == "register"
            d = "1"
            w = "1"
            mod ="11"
            result = "100010"
            reg = $register_codes[first.value] 
            rm = $register_codes[second.value]
            result +=  +d+w +mod +reg+rm

            result = converto16(result)

        elsif first.type == "register" && second.type == "memory"
            w = "1"
            d = "1"
            mod = ""
            rm = ""
            result = "100010"
            substrings = second.value.scan(/\w+|\W/)  
            register = substrings[1]
            displacement = substrings[3].to_i
        
            unless $baseRegisters.include?(register)
            erorrsWriter("Ошибка! Нельзя выполнить базовую адресацию с данным регистром #{register},   строка : #{$current_line_number}")
            return nil
            end
        
            mod = displacement > 255 ? "10" : "01"
            tb = sprintf('%016b', displacement)
            rm = register == "BP" ? "110" : "111"
            reg = $register_codes[first.value] 
            displacement > 255 ? tb = reveseByts(sprintf('%016b', displacement)) : tb = sprintf('%08b', displacement)
            
            result  += w + d + mod + reg + rm + tb
            result = converto16(result)
            
            
        elsif first.type == "memory" && second.type == "register"  
            w = "1"
            d = "0"
            mod = ""
            rm = ""
            result = "100010"
            substrings = first.value.scan(/\w+|\W/)  
            register = substrings[1]
            displacement = substrings[3].to_i
        
            unless $baseRegisters.include?(register)
                erorrsWriter("Ошибка! Нельзя выполнить базовую адресацию с данным регистром #{register},   строка : #{$current_line_number}")
            return nil
            end
        
            mod = displacement > 255 ? "10" : "01"
            tb = sprintf('%016b', displacement)
            rm = register == "BP" ? "110" : "111"
            reg = $register_codes[second.value] 
            displacement > 255 ? tb = reveseByts(sprintf('%016b', displacement)) : tb = sprintf('%08b', displacement)
            
            result  +=d + w + mod + reg + rm + tb
            result = converto16(result)
        elsif first.type == "register" && second.type == "direct" 
            result = "1011"
            w = "1"
            reg = $register_codes[first.value] 
            binary_string = sprintf('%016b', second.value)
            result += w + reg + reveseByts(binary_string)
            result = converto16(result)
        else
            erorrsWriter("Ошибка! Неправильно указаны операнды #{first.value}|#{second.value},   строка : #{$current_line_number}")
        end 
        $listing << format_output($current_line_number,$current_loc, result, "MOV #{first.value}, #{second.value}")
        changeloc(result)
        $machineCode << result
    end

    def changeloc(line)
        $current_line_number+=1
        $current_loc +=line.length/2
    end

    def ADC (first,second)
        result =""
        

        if first.type == "register" && second.type == "register"
            result = "000100"
            d = "1"
            w = "1"
            mod = "11"
            reg = $register_codes[first.value]
            rm = $register_codes[second.value]
            result +=  +d+w +mod +reg+rm
            result = converto16(result)
        elsif first.type == "register" && second.type == "memory"
            w = "1"
            d = "1"
            mod = ""
            rm = ""
            result = "000100"
            substrings = second.value.scan(/\w+|\W/)  
            register = substrings[1]
            displacement = substrings[3].to_i
            unless $baseRegisters.include?(register)
                erorrsWriter("Ошибка! Нельзя выполнить базовую адресацию с данным регистром #{register},   строка : #{$current_line_number}")
                return nil
            end

            mod = displacement > 255 ? "10" : "01"

            rm = register == "BP" ? "110" : "111"
            reg = $register_codes[first.value] 
            tb = displacement > 255 ? reveseByts(sprintf('%016b', displacement)) : sprintf('%08b', displacement)
            
            result  +=d + w + mod + reg + rm + tb
            result = converto16(result)
            
        elsif first.type == "memory" && second.type == "register"  
            w = "1"
            d = "0"
            result = "000100"
            substrings = first.value.scan(/\w+|\W/)  
            register = substrings[1]
            displacement = substrings[3].to_i
        
            unless $baseRegisters.include?(register)
                erorrsWriter("Ошибка! Нельзя выполнить базовую адресацию с данным регистром #{register},   строка : #{$current_line_number}")
                return nil
            end

            mod = displacement > 255 ? "10" : "01"

            rm = register == "BP" ? "110" : "111"
            reg = $register_codes[second.value] 
            displacement > 255 ? tb = reveseByts(sprintf('%016b', displacement)) : tb = sprintf('%08b', displacement)
            
            result  +=d + w + mod + reg + rm + tb
            result = converto16(result)

            
            
        elsif first.type == "register" && second.type == "direct" 
            result = "100000"
            s = "1"
            w = "1"
            mod = "11"
            second.value.to_i > 127 ? s = "0" : s = "1"
            s== "0" ? binary_string = sprintf('%016b', second.value) : binary_string = sprintf('%08b', second.value)
            rm = $register_codes[first.value]
            
            result +=  s+w + mod + "010"+rm +reveseByts(binary_string)

            result =converto16(result)
        else
            erorrsWriter("Ошибка! Неправильно указаны операнды #{first.value}|#{second.value},   строка : #{$current_line_number}")
        end 
        $listing << format_output($current_line_number,$current_loc, result, "ADC #{first.value}, #{second.value}")
        changeloc(result)
        $machineCode << result
    end   
   
    def IDIV(operand)
        result =""
        if  operand.type =="memory"
            w = "0"
            result = "1111011"
            substrings = operand.value.scan(/\w+|\W/)  
            register = substrings[1]
            displacement = substrings[3].to_i
        
            unless $baseRegisters.include?(register)
            erorrsWriter("Ошибка! Нельзя выполнить базовую адресацию с данным регистром #{register},   строка : #{$current_line_number}")
            return nil
            end

            mod = displacement > 255 ? "10" : "01"

            rm = register == "BP" ? "110" : "111"
            
            displacement > 255 ? tb = reveseByts(sprintf('%016b', displacement)) : tb = sprintf('%08b', displacement)
            
            result  += w + mod +"111" + rm + tb
            result = converto16(result)
            else
                perorrsWriter("Ошибка! Неправильно указан операнд #{operand.value}|,   строка : #{$current_line_number}")
        end
        $listing << format_output($current_line_number,$current_loc, result, "MOV #{operand.value}")
        changeloc(result)
        $machineCode << result
    end

    def LABEL(label)
        $listing << format_output($current_line_number,$current_loc, "", "#{label.name}")
        $current_line_number+=1
        $metaLabel = label   
        if $flag == 1
            result = "01111101"
            sb =  $metaLabel.address - $jgeloc
            sb = sprintf('%08b', sb) 
            result += sb
            result = converto16(result)
            
            $listing.each do |line|
                if line.include?("JGE")
                line.gsub!("7D", result)
                puts line
              end
            end
   
            $machineCode.map! { |element| element == "7D" ? "#{result}" : element }  
        end
    end

    def JGE(operand)
        result = "01111101"
        if $metaLabel.address != -1 
            sb =  $metaLabel.address - ($current_loc+2) if $metaLabel.address !=-1 
            sb = (sb & 0xff).to_s(2).rjust(8, '0')
             
            result += sb
            result = converto16(result)
            $listing << format_output($current_line_number,$current_loc, result, "JGE #{operand.value}")
            changeloc(result)
            $machineCode << result
        else
            result = converto16(result)
            $listing << format_output($current_line_number,$current_loc, result, "JGE #{operand.value}")
            $current_line_number+=1
            $jgeloc = $current_loc + 2
            $current_loc+=2
            $machineCode << result
            $flag = 1 
  
        end
    end

    def SEGMENT(operand)
        $segmentName = operand.value
        $segmentStart_loc = $current_loc
        $listing << format_output($current_line_number, $current_loc, "", "SEGMENT #{operand.value}")
        $current_line_number+=1
    end    
    def ENDS(operand)
        $segmentEnds_loc = $current_loc
        $listing << format_output($current_line_number, $current_loc, "", "ENDS #{operand.value}")
        $current_line_number+=1
    end
    def ENDPROG
        $listing << format_output($current_line_number, $current_loc, "", "END")
        $current_line_number+=1
    end
    def ORG(operand)
        match = operand.value.match(/\A(\d+)/)
        if match
          $orgsize = operand.value.to_i(16)
          $listing << format_output($current_line_number, $current_loc, "", "ORG #{operand.value}")
          $current_loc += $orgsize
          $current_line_number += 1
        end
    end
    def INT(operand)
        result = "11001101"
        match = operand.value.match(/\A(\d+)/)
          
          result = converto16(result)
          result += match[1]

          $listing << format_output($current_line_number, $current_loc, result, "INT #{operand.value}")
          changeloc(result)
          $machineCode << result
    end
    def DW(var)
        number = var.value.to_i(16)
        result = "%04X" % number

        # Разделение на две половины
        half1 = result[2..3]
        half2 = result[0..1]

        # Формирование строки "01 00"
        final_result = "#{half1} #{half2}"

        $listing << format_output($current_line_number, $current_loc, final_result, "#{var.name} DW #{var.value}")
        $current_loc += 2
        $current_line_number += 1
        $machineCode << final_result
        
    end
    def reveseByts(string)
        
        byte1 = string[0, 8]
        byte2 = string[8, 8]
        reversed_string = byte2 + byte1
        return reversed_string
        
    end
    def converto16(result)
        hex_string = result.to_i(2).to_s(16)
        hex_string.upcase
    end


def format_output(line_number, location, machine_code, source)
    line_number = line_number.to_i
    location = location.to_i

    hex_loc = sprintf('%04X', location)
    line = "[%6s]    %8s    %-35s %s\n" % [line_number, hex_loc, machine_code, source]
    return line
  end
  $output_lines = []

  def generateListing 
    file_path = "output.txt"  # Путь к файлу для записи
    
    output_lines = []
    output_lines << "==================================================================================================="
    output_lines << "[LINE]     LOC: MACHINE CODE                          SOURCE"
    output_lines << "==================================================================================================="
    
    File.open(file_path, "w") do |file|
        output_lines.each { |line| file.puts(line) }
    end 
    

    end
    def generateObjectcode
        file_path = "object.txt"  # Путь к файлу для записи
        mc = $machineCode.join
        output_lines = "H#{$segmentName}#{$orgsize.to_s(16)}#{$current_loc.to_s(16)}T#{$orgsize.to_s(16)}#{$current_loc.to_s(16)}#{mc}E#{$orgsize.to_s(16)}"
        
        File.open(file_path, "w") { |file| file.puts(output_lines) }
        
    
    end

def addLineToListing(lines)
    file_path = "output.txt"  # Путь к файлу для записи
    File.open(file_path, "a") { |file| file.puts(lines) }
end
def erorrsWriter(line)
    file_path = "erorrs.txt"  # Путь к файлу для записи
    File.open(file_path, "a") { |file| file.puts(line) }
end
def generateErorrsFile
    file_path = "erorrs.txt" 
    File.open(file_path, "w")
    
end
generateListing()
generateErorrsFile()
parser = Parser.new("input.txt")
parser.parse
addLineToListing($listing)
generateObjectcode()
  
  
  
  
