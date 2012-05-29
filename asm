#!/usr/bin/env ruby
# asm.rb -- assembler for Mojang's fictional 1985 DCPU-16
# hh 04apr12 started
# hh 06apr12 generate listing and object file, added DAT
# hh 28apr12 adapted to DCPU 1.5, added INCLUDE, macros
# hh 03may12 fix INCLUDE listing darkness
# hh 06may12 fix handling of negative literals

# TODO:
# do not list INCLUDEs as line 0 of included file
# do not list data if ORG bumps $pc forward

WORD = 0xffff
BASIC_OPCODES = %w(- SET ADD SUB MUL MLI DIV DVI MOD MDI AND BOR XOR SHR ASR SHL IFB IFC IFE IFN IFG IFA IFL IFU - - ADX SBX - - STI STD)
SPECIAL_OPCODES = %w(- JSR - - - - - HCF INT IAG IAS IAP IAQ - - - HWN HWQ HWI)
REGS = %w(A B C X Y Z I J)
EXTRAS = %w(- PEEK - SP PC EX)

REG = /[ABCXYZIJ]/
LABEL = /[A-Za-z$_][A-Za-z0-9$_]*/
LITERAL = /-?\d{1,5}|0[xX][0-9a-fA-F]{1,4}/

$mem = Array.new(0x1_0000, 0)
$labels = Hash.new
$errors = 0
$link = 0   # macro variable for CamelForth headers

def err(msg)
  $stderr.puts "#{File.basename($f.last.path)}:#{$f.last.lineno} #{msg}"
  $errors += 1
end

# deposit a word in memory, advancing PC
def comma(w)
  $mem[$pc & WORD] = (w & WORD)
  $pc += 1
end

SOME_VALUE = 040   # not a compact literal

def lookup(label)
  if $pass == 1
    $labels.fetch(label, SOME_VALUE)
  else
    $labels.fetch(label) {|k| err("undefined label: #{label}"); SOME_VALUE }
  end
end

def word(s)
  s.to_i(0) & WORD    # accept 0x
end

def asm_operand(op)
  case op
    when /^#{REG}$/
      REGS.index(op)
    when /^\[(#{REG})\]$/
      010+REGS.index($1)
    when /^\[(#{LITERAL})\+(#{REG})\]$/
      comma(word($1))
      020+REGS.index($2)
    when /^\[(#{LABEL})\+(#{REG})\]$/
      comma(lookup($1))
      020+REGS.index($2)
    when /^(PUSH|POP)$/
      030   # TODO error checking a/b
    when /^(PEEK|SP|PC|EX)$/
      030+EXTRAS.index(op)
    when /^\[SP\+(#{LITERAL})\]$/   # TODO allow LABEL
      comma($1)
      032
    when /^\[(#{LITERAL})\]$/
      comma(word($1))
      036
    when /^\[(#{LABEL})\]$/
      comma(lookup($1))
      036
    when /^(#{LITERAL})$/
      lit = word($1)
      if lit == 0xffff
        040
      elsif (0..30) === lit
        040+(lit+1)
      else
        comma(lit)
        037
      end
    when /^(#{LABEL})$/
      comma(lookup($1)) # TODO use short form if backref
      037
    else
      raise "bad operand: #{op}"
  end
end

def resolve(opd)
  return case opd
    when /^#{LITERAL}$/
      word(opd)
    when /^#{LABEL}$/
      lookup(opd.upcase)
    else
      err("bad expression: #{opd}") if $pass == 1
      0
  end
end

def data(opd)
  case opd
    when /^"(.*)"$/, /^'(.*)'$/
      $1.codepoints.each {|u| comma(u) }
    else
      comma(resolve(opd))
  end
end

def asm_opcode(opc, opds)
  case opc
    when 'DAT', 'DW'
      opds.each {|opd| data(opd) }
    when 'INCLUDE'
      $f << File.open(opds.shift+".dasm", "r")
    when 'HEAD', 'IMMED'
      label, name, action = opds
      comma($link)
      comma(opc == 'IMMED' ? 1 : 0)
      $labels['$LINK'] = $link = $pc
      comma(name.length()-2)    # sans quotes
      data(name)
      deflab(label.upcase, $pc)
      unless action.upcase == "DOCODE"
        comma(0x7c20)           # JSR addr
        comma(lookup(action.upcase))
      end
    when 'NEXT'
      comma(0x3401)
      comma(0x88a2)
      comma(0x0381)
    when 'ORG'
      $list_pc = $pc = resolve(opds.shift)
    else
      a = b = 0
      pc = $pc
      comma(0)   # allocate instruction early on
      o = if b = SPECIAL_OPCODES.index(opc)
        a = asm_operand(opds.shift.upcase) 
        0
      elsif o = BASIC_OPCODES.index(opc)
        # processor handles a first, then b
        bop = opds.shift.upcase
        a = asm_operand(opds.shift.upcase)
        b = asm_operand(bop) & 037  # TODO error checking
        raise "too many operands" unless opds.empty?
        o
      else
        err "bad opcode #{opc}" if $pass == 1
        return
        0
      end
      $mem[pc] = (a << 10) | (b << 5) | o
  end
end

def tokenize(line)
  tokens = line.scan(/:[\w$]+|;.*|,|"[^"]*"|'[^']*'|[-\w$\[\]\+]+/)
  tokens.delete(',')
  comment = tokens.find_index {|t| t =~ /^;/ }
  tokens = tokens[0, comment] unless comment.nil?
  tokens
end

def deflab(label, value)
  if $labels.include?(label) && $labels[label] != value
    err "duplicate definition of #{label}" if $pass == 1
  else
    $labels[label] = value
  end
end

def asm_line(line)
  tokens = tokenize(line)
  return if tokens.empty?
  while tokens.first.start_with?(':')
    label = tokens.shift.sub(/^:/, '')
    if $pass == 1
      deflab(label.upcase, $pc)
    else
      err "phase error" if $pc != $labels[label.upcase]
    end
    return if tokens.empty?   # allow labels-only lines
  end
  opcode = tokens.shift.upcase
  asm_opcode(opcode, tokens)
end

def word_if(addr, used)
  used ? "%04x" % $mem[addr] : ''
end

def list_line(line, pc)
  len = $pc - pc
  $listing.printf("%04x  %-4s %-4s %-4s\t%4d %s\n",
    pc, word_if(pc, len >= 1), word_if(pc+1, len >= 2), word_if(pc+2, len >= 3),
    $f.last.lineno, line
  )
  if len > 3
    len -= 3
    while len > 0
      pc += 3
      $listing.printf("%04x  %-4s %-4s %-4s\t%4d\n",
        pc, word_if(pc, len >= 1), word_if(pc+1, len >= 2), word_if(pc+2, len >= 3),
        $f.last.lineno
      )
      len -= 3
    end
  end
end

def asm_file(f)  # f rewindable
  $f = Array.new
  $f << f
  while !$f.empty?
    line = $f.last.gets
    if line
      line.chomp!
      $list_pc = $pc
      asm_line(line)
      list_line(line, $list_pc) if $pass == 2
    else
      $f.pop
    end
  end
end

def dump_syms(f)
  f.puts "\nSYMBOL TABLE\n\n"
  $labels.sort.each {|k,v| f.printf("%-10s %04x\n", k, v) }
end

def save_obj(fn)
  File.open(fn, "wb") {|f|
    f.write $mem[0, $pc].pack("n*")
  }
end

def asm_fn(ifn, ofn)
  File.open(ifn, "r") {|f|
    $pass = 1
    $pc = $link = 0
    asm_file(f)
    f.rewind
    $pass = 2
    $pc = $link = 0
    $listing = File.open(File.basename(ifn, ".dasm") + ".lst", "w")
    asm_file(f)
    #dump_syms($listing)
    $listing.close
    save_obj(ofn)
  }
end

if $0 == __FILE__
  unless ARGV.length == 1 || ARGV.length == 3
    $stderr.puts "usage: #{File.basename($0, '.rb')} [-o output.o] input.dasm"
    exit(1)
  end
  ofn = nil
  if ARGV.first == '-o'
    ofn = ARGV.shift(2).last
  end
  ifn = ARGV.shift
  ofn = File.basename(ifn, '.dasm') + '.o' if ofn.nil?
  asm_fn(ifn, ofn)
  puts "#{$errors} errors" if $errors > 0
  exit($errors == 0 ? 0 : 1)
end
